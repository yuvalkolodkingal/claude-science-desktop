const { app, BrowserWindow, shell, Menu, dialog, session, net } = require('electron');
const { execFile, spawn, execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const fsExistsSync = (p) => { try { return fs.existsSync(p); } catch { return false; } };

// ---------------------------------------------------------------------------
// Unofficial desktop wrapper for Claude Science. Not affiliated with Anthropic.
//
// This app ships no Anthropic code. It locates an existing `claude-science`
// install, or downloads the official build from downloads.claude.ai on first
// run and verifies it against the sha256 Anthropic publishes in its manifest.
// It then starts that daemon, gets a single-use login link, and shows the local
// web UI in a native window.
// ---------------------------------------------------------------------------

// Inside Flatpak the daemon cannot run in the sandbox at all: Claude Science
// sandboxes its agent with bubblewrap, and creating that nested user namespace
// is blocked here. So it runs on the host via flatpak-spawn, where its own
// sandbox works, and only this UI stays sandboxed.
const IN_FLATPAK = Boolean(process.env.FLATPAK_ID) || fsExistsSync('/.flatpak-info');

const DOWNLOAD_BASE = 'https://downloads.claude.ai/claude-science';
const MANIFEST_URL = `${DOWNLOAD_BASE}/latest/manifest.json`;
const PLATFORM_KEY = 'linux-x64';

const STARTUP_TIMEOUT_MS = 90_000;
const POLL_INTERVAL_MS = 500;

let BIN = null;             // resolved path to the claude-science executable
let mainWindow = null;
let daemonProc = null;
let weStartedDaemon = false;
let daemonOrigin = null;
let quitting = false;
let stopDaemonOnQuit = true;
let signInAttempts = 0;

// Pin the window identity so the shell matches it to the .desktop entry.
app.setName('Claude Science Desktop');
app.commandLine.appendSwitch('class', 'claude-science-desktop');

if (!app.requestSingleInstanceLock()) {
  app.quit();
}

// --- locating the daemon ---------------------------------------------------

function managedBinPath() {
  // In Flatpak this must be a real host path, because the host executes it.
  if (IN_FLATPAK) {
    return process.env.CLAUDE_SCIENCE_HOST_BIN ||
      path.join(app.getPath('home'), '.local', 'share', 'claude-science-desktop', 'bin', 'claude-science');
  }
  return path.join(app.getPath('userData'), 'bin', 'claude-science');
}

// Build the argv for running the daemon. Sandboxed, that means handing it to
// the host through flatpak-spawn; otherwise it is a plain exec.
function daemonCmd(args) {
  if (IN_FLATPAK) return ['flatpak-spawn', ['--host', BIN, ...args]];
  return [BIN, args];
}

function onPath() {
  try {
    const argv = IN_FLATPAK
      ? ['flatpak-spawn', ['--host', 'sh', '-c', 'command -v claude-science']]
      : ['sh', ['-c', 'command -v claude-science']];
    return execFileSync(argv[0], argv[1], { encoding: 'utf8' }).trim() || null;
  } catch {
    return null;
  }
}

function isExecutableFile(p) {
  try {
    return Boolean(p) && fs.statSync(p).isFile() && (fs.accessSync(p, fs.constants.X_OK), true);
  } catch {
    return false;
  }
}

// Order: explicit override, Flatpak extra-data, a normal install on PATH, our
// own managed copy, then the dev checkout.
function resolveBinary() {
  const candidates = [
    process.env.CLAUDE_SCIENCE_BIN,
    // Placed next to the executable by the .deb/.rpm post-install hook.
    path.join(path.dirname(process.execPath), 'bin', 'claude-science'),
    onPath(),
    managedBinPath(),
    path.join(__dirname, 'vendor', 'claude-science'),
  ];
  const found = candidates.find(isExecutableFile);
  if (found) return found;

  // Under Flatpak the host's copy may be outside anything we can stat; if the
  // host reports one on its PATH, take it at its word.
  if (IN_FLATPAK) {
    const hostHit = onPath();
    if (hostHit) return hostHit;
  }
  return null;
}

// --- first-run download ----------------------------------------------------

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const request = net.request(url);
    request.on('response', (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`${url} returned HTTP ${response.statusCode}`));
        return;
      }
      let body = '';
      response.on('data', (c) => { body += c; });
      response.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (err) {
          reject(new Error(`could not parse ${url}: ${err.message}`));
        }
      });
    });
    request.on('error', reject);
    request.end();
  });
}

function downloadTo(url, dest, onProgress) {
  return new Promise((resolve, reject) => {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    const tmp = `${dest}.part`;
    const out = fs.createWriteStream(tmp);
    const hash = crypto.createHash('sha256');
    let received = 0;

    const request = net.request(url);
    request.on('response', (response) => {
      if (response.statusCode !== 200) {
        out.destroy();
        reject(new Error(`${url} returned HTTP ${response.statusCode}`));
        return;
      }
      const total = Number(response.headers['content-length']) || 0;
      response.on('data', (chunk) => {
        received += chunk.length;
        hash.update(chunk);
        out.write(chunk);
        if (onProgress) onProgress(received, total);
      });
      response.on('end', () => {
        out.end(() => resolve({ tmp, digest: hash.digest('hex') }));
      });
      response.on('error', reject);
    });
    request.on('error', reject);
    request.end();
  });
}

async function downloadDaemon(onProgress) {
  if (process.platform !== 'linux' || process.arch !== 'x64') {
    throw new Error(
      `no Claude Science build for ${process.platform}-${process.arch}. Install it yourself ` +
      'and point CLAUDE_SCIENCE_BIN at the executable.'
    );
  }

  onProgress({ phase: 'manifest' });
  const manifest = await fetchJson(MANIFEST_URL);
  const version = manifest.version;
  const expected = manifest.sha256 && manifest.sha256[PLATFORM_KEY];
  if (!version || !expected) {
    throw new Error('release manifest is missing a version or a linux-x64 checksum');
  }

  const dest = managedBinPath();
  const url = `${DOWNLOAD_BASE}/${version}/${PLATFORM_KEY}`;
  console.log(`[wrapper] downloading claude-science ${version} from ${url}`);

  const { tmp, digest } = await downloadTo(url, dest, (received, total) => {
    onProgress({ phase: 'download', version, received, total });
  });

  // Anthropic publishes the checksum; refuse anything that doesn't match it.
  if (digest !== expected) {
    fs.unlinkSync(tmp);
    throw new Error(`checksum mismatch for ${url}\n  expected ${expected}\n  got      ${digest}`);
  }

  fs.chmodSync(tmp, 0o755);
  fs.renameSync(tmp, dest);
  console.log(`[wrapper] verified sha256 ${digest}`);
  return dest;
}

// --- daemon control --------------------------------------------------------

function run(args, { timeout = 20_000 } = {}) {
  const [cmd, argv] = daemonCmd(args);
  return new Promise((resolve) => {
    execFile(cmd, argv, { timeout, maxBuffer: 4 * 1024 * 1024 }, (error, stdout, stderr) => {
      resolve({ error, stdout: String(stdout || ''), stderr: String(stderr || '') });
    });
  });
}

async function status() {
  const { stdout } = await run(['status']);
  try {
    return JSON.parse(stdout);
  } catch {
    return null;
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function startDaemon() {
  const [cmd, argv] = daemonCmd(['serve', '--no-browser']);
  daemonProc = spawn(cmd, argv, {
    stdio: 'ignore',
    detached: true,
    env: process.env,
  });
  daemonProc.unref();
  weStartedDaemon = true;

  daemonProc.on('exit', (code, signal) => {
    daemonProc = null;
    if (!quitting) {
      dialog.showErrorBox(
        'Claude Science stopped',
        `The claude-science daemon exited (code ${code}, signal ${signal || 'none'}).\n` +
        'Check its logs with: claude-science logs --tail'
      );
    }
  });
}

async function waitForDaemon() {
  const deadline = Date.now() + STARTUP_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const s = await status();
    if (s && s.running) return s;
    if (daemonProc === null && weStartedDaemon) throw new Error('daemon exited during startup');
    await sleep(POLL_INTERVAL_MS);
  }
  throw new Error('timed out waiting for the claude-science daemon to start');
}

function stopDaemon() {
  try {
    const [cmd, argv] = daemonCmd(['stop']);
    execFileSync(cmd, argv, { timeout: 15_000, stdio: 'ignore' });
  } catch {
    if (daemonProc) daemonProc.kill('SIGTERM');
  }
}

async function loginUrl() {
  const { error, stdout, stderr } = await run(['url']);
  const url = stdout.trim().split('\n').pop().trim();
  if (error || !/^https?:\/\//.test(url)) {
    throw new Error(`could not get a login link: ${stderr.trim() || (error && error.message) || stdout.trim()}`);
  }
  return url;
}

// --- window ----------------------------------------------------------------

function isInternal(urlString) {
  try {
    const u = new URL(urlString);
    if (!daemonOrigin) return false;
    const d = new URL(daemonOrigin);
    // The daemon also serves generated HTML previews on port+1.
    return u.hostname === d.hostname && (u.protocol === 'http:' || u.protocol === 'https:');
  } catch {
    return false;
  }
}

function openExternal(urlString) {
  try {
    const { protocol } = new URL(urlString);
    if (['https:', 'http:', 'mailto:'].includes(protocol)) shell.openExternal(urlString);
  } catch {
    /* ignore malformed URLs */
  }
}

function setStatus(text, detail) {
  if (!mainWindow) return;
  const payload = JSON.stringify({ text, detail: detail || '' });
  mainWindow.webContents
    .executeJavaScript(`window.setStartupStatus && window.setStartupStatus(${payload})`, true)
    .catch(() => { /* the page already navigated away */ });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 640,
    minHeight: 520,
    backgroundColor: '#1f1e1d',
    autoHideMenuBar: true,
    icon: path.join(__dirname, 'build', 'icon.png'),
    title: 'Claude Science Desktop',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: true,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'loading.html'));
  mainWindow.on('page-title-updated', (e) => e.preventDefault());

  mainWindow.webContents.on('did-finish-load', () => {
    handleSignInPage().catch(() => { /* leave the page; the button still works */ });
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isInternal(url)) {
      const child = new BrowserWindow({
        width: 1100,
        height: 800,
        backgroundColor: '#1f1e1d',
        autoHideMenuBar: true,
        webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true },
      });
      child.loadURL(url);
      return { action: 'deny' };
    }
    openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!isInternal(url) && !url.startsWith('file://')) {
      event.preventDefault();
      openExternal(url);
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function showFailure(message) {
  if (!mainWindow) return;
  const esc = (s) => s.replace(/[<&]/g, (c) => (c === '<' ? '&lt;' : '&amp;'));
  mainWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(
    `<body style="background:#1f1e1d;color:#e8e6e3;font:14px/1.6 system-ui,sans-serif;padding:48px">
     <h1 style="font-size:20px;color:#d97757">Claude Science couldn't start</h1>
     <pre style="white-space:pre-wrap;color:#bdb9b4">${esc(message)}</pre>
     <p style="color:#8f8a85">Logs: <code>claude-science logs --tail</code></p>
     </body>`
  )}`);
}

// The daemon's login page is a one-click form POST (a gate so link prefetchers
// can't burn the single-use nonce). We asked for that nonce on the user's
// behalf a moment ago, so submit it for them.
async function handleSignInPage() {
  if (!mainWindow || !daemonOrigin) return;
  if (!mainWindow.webContents.getURL().startsWith(daemonOrigin)) return;

  const state = await mainWindow.webContents.executeJavaScript(
    `(() => {
       if (document.querySelector('form[action$="api/auth/nonce"] button[type=submit]')) return 'form';
       const t = (document.body && document.body.innerText || '').slice(0, 2000);
       return /signed out|session expired|claude-science url/i.test(t) ? 'expired' : 'ok';
     })()`,
    true
  );

  if (state === 'expired' && signInAttempts < 3) {
    signInAttempts += 1;
    console.log('[wrapper] session expired, fetching a fresh login link');
    mainWindow.loadURL(await loginUrl());
    return;
  }

  if (state !== 'form') {
    if (signInAttempts > 0) console.log('[wrapper] signed in');
    signInAttempts = 0;
    return;
  }

  if (signInAttempts >= 3) return;   // give up; let the user click it
  signInAttempts += 1;

  // Second pass means the nonce we had was stale — fetch a fresh one and submit
  // that page on the next pass.
  if (signInAttempts === 2) {
    mainWindow.loadURL(await loginUrl());
    return;
  }

  console.log(`[wrapper] sign-in page detected, submitting nonce (attempt ${signInAttempts})`);
  await mainWindow.webContents.executeJavaScript(
    `document.querySelector('form[action$="api/auth/nonce"] button[type=submit]').click()`,
    true
  );
}

async function boot() {
  try {
    BIN = resolveBinary();
    if (!BIN) {
      BIN = await downloadDaemon((p) => {
        if (p.phase === 'manifest') {
          setStatus('Checking for the Claude Science release…', 'One-time download from downloads.claude.ai');
        } else {
          const mb = (n) => (n / 1024 / 1024).toFixed(0);
          const pct = p.total ? ` — ${Math.round((p.received / p.total) * 100)}%` : '';
          setStatus(
            `Downloading Claude Science ${p.version}${pct}`,
            `${mb(p.received)} MB of ${p.total ? `${mb(p.total)} MB` : '?'} · verified against Anthropic's published checksum`
          );
        }
      });
    }
    console.log(`[wrapper] using ${BIN}${IN_FLATPAK ? ' (run on host via flatpak-spawn)' : ''}`);

    setStatus('Starting the Claude Science daemon…');
    let s = await status();
    const daemonWasAlreadyUp = Boolean(s && s.running);
    if (!daemonWasAlreadyUp) {
      startDaemon();
      s = await waitForDaemon();
    }

    signInAttempts = 0;
    setStatus('Signing in…');

    // Always start from a fresh login link: sessions don't survive a daemon
    // restart, and the link is free. did-finish-load submits the form.
    const url = await loginUrl();
    daemonOrigin = new URL(url).origin;
    console.log(
      `[wrapper] ${daemonWasAlreadyUp ? 'reusing daemon' : 'daemon ready'} at ${daemonOrigin}, loading UI`
    );
    if (mainWindow) mainWindow.loadURL(url);
  } catch (err) {
    showFailure(err && err.message ? err.message : String(err));
  }
}

function aboutBox() {
  dialog.showMessageBox(mainWindow, {
    type: 'info',
    title: 'About Claude Science Desktop',
    message: 'Claude Science Desktop',
    detail:
      'An unofficial, community-built desktop window for Claude Science.\n\n' +
      'Not affiliated with, endorsed by, or supported by Anthropic. ' +
      '"Claude" and "Claude Science" are trademarks of Anthropic PBC, used here only ' +
      'to describe what this wrapper opens.\n\n' +
      'Claude Science itself is downloaded from Anthropic and is covered by ' +
      "Anthropic's own terms. This wrapper is MIT-licensed:\n" +
      'https://github.com/yuvalkolodkingal/claude-science-desktop\n\n' +
      `Daemon: ${BIN || 'not resolved yet'}`,
    buttons: ['Close'],
  });
}

function buildMenu() {
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {
      label: 'File',
      submenu: [
        {
          label: 'New Login Link (reload UI)',
          accelerator: 'CmdOrCtrl+Shift+R',
          click: async () => {
            try {
              const url = await loginUrl();
              daemonOrigin = new URL(url).origin;
              signInAttempts = 0;
              if (mainWindow) mainWindow.loadURL(url);
            } catch (err) {
              showFailure(err.message);
            }
          },
        },
        { label: 'Open in Browser', click: () => daemonOrigin && openExternal(daemonOrigin) },
        { type: 'separator' },
        { role: 'quit' },
        {
          label: 'Quit (leave daemon running)',
          click: () => {
            stopDaemonOnQuit = false;
            app.quit();
          },
        },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' }, { role: 'redo' }, { type: 'separator' },
        { role: 'cut' }, { role: 'copy' }, { role: 'paste' }, { role: 'selectAll' },
      ],
    },
    {
      label: 'View',
      submenu: [
        { role: 'reload' }, { role: 'forceReload' }, { type: 'separator' },
        { role: 'resetZoom' }, { role: 'zoomIn' }, { role: 'zoomOut' }, { type: 'separator' },
        { role: 'togglefullscreen' }, { role: 'toggleDevTools' },
      ],
    },
    {
      label: 'Help',
      submenu: [
        { label: 'About (unofficial wrapper)', click: aboutBox },
        {
          label: 'Claude Science by Anthropic',
          click: () => openExternal('https://claude.com/product/claude-science'),
        },
        {
          label: 'Wrapper Source & Issues',
          click: () => openExternal('https://github.com/yuvalkolodkingal/claude-science-desktop'),
        },
      ],
    },
  ]));
}

app.whenReady().then(() => {
  session.defaultSession.setPermissionRequestHandler((_wc, permission, callback) => {
    callback(['clipboard-read', 'clipboard-sanitized-write', 'media', 'notifications', 'fullscreen'].includes(permission));
  });

  buildMenu();
  createWindow();
  boot();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
      boot();
    }
  });
});

app.on('second-instance', () => {
  if (mainWindow) {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  }
});

app.on('before-quit', () => {
  quitting = true;
  // Stop the daemon this app started; one that was already running belongs to
  // someone else.
  if (stopDaemonOnQuit && weStartedDaemon && BIN) stopDaemon();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
