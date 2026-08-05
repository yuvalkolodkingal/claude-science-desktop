# How it works

The wrapper is one Electron main process ([`main.js`](https://github.com/yuvalkolodkingal/claude-science-desktop/blob/main/main.js))
with no npm runtime dependencies. It does four things.

## 1. Find the daemon

In order: `CLAUDE_SCIENCE_BIN`, `claude-science` on `PATH`, its own managed copy
in the app's user-data directory, then `vendor/claude-science` for dev checkouts.

If none exists, it downloads `https://downloads.claude.ai/claude-science/<version>/linux-x64`,
where `<version>` comes from Anthropic's `latest/manifest.json`, and compares the
SHA-256 against the one in that manifest. A mismatch deletes the file and aborts
— nothing unverified is ever executed.

## 2. Start it

`claude-science status` first: a daemon already running (yours from a terminal,
or one left over) is reused rather than restarted. Otherwise the app spawns
`claude-science serve --no-browser` detached and polls `status` until it reports
`running`, up to 90 s. Cold start is ~10–15 s, mostly MCP connector warmup, shown
behind a loading screen.

## 3. Sign in without the click

`claude-science url` returns a single-use login link (~3 min TTL). That URL
doesn't log you straight in — it serves a small form that POSTs the nonce, a
deliberate gate so link prefetchers and scanners can't burn a one-time token.

Since the app requested that nonce itself, a moment earlier, on your behalf, it
submits the form for you. If a page comes back "You've been signed out" it
fetches a fresh link and retries — twice, then it leaves the button alone so a
real failure stays visible instead of looping.

Sessions do not survive a daemon restart, so every launch starts from a fresh
link. **File → New Login Link** forces one manually.

## 4. Window and link policy

- The daemon's UI (`127.0.0.1:8000`) and its generated HTML previews (`:8001`)
  open in-app; previews get their own window.
- Everything else goes to your system browser.
- Window identity is pinned (`--class=claude-science-desktop`) so the desktop
  shell matches the window to the `.desktop` entry and shows the right name and
  icon rather than a raw app id.
- A second launch focuses the existing window instead of starting a rival
  instance.

## Daemon lifecycle on quit

Quitting stops the daemon **the app started**. A daemon that was already running
when the app launched is left alone. **File → Quit (leave daemon running)** skips
the shutdown for that one quit.
