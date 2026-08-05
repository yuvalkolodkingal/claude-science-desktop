# Claude Science Desktop

**The Linux desktop app for [Claude Science](https://claude.com/product/claude-science).**
Anthropic ships an official desktop app for macOS but not for Linux — only the
`claude-science` daemon and its browser UI. This starts that daemon, signs you
in, and shows the UI in a native window instead of a browser tab.

> **Unofficial.** Not affiliated with, endorsed by, or supported by Anthropic.
> No Anthropic code is redistributed here — the app downloads Claude Science from
> Anthropic's own servers on first run and verifies it against Anthropic's
> published checksum. See [NOTICE.md](NOTICE.md).

## Install

**Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh
```

It detects your distro and offers a native package (`.deb`, `.rpm`, pacman), a
Flatpak, or a no-sudo portable install. Skip the prompt with
`| sh -s -- --native`, `--flatpak`, or `--portable`.

Or grab a package directly from [Releases](https://github.com/yuvalkolodkingal/claude-science-desktop/releases/latest).

**On macOS, use Anthropic's official app instead** — it is signed and notarized:
[mac-arm64.dmg](https://downloads.claude.ai/claude-science/latest/mac-arm64.dmg) ·
[mac-x64.dmg](https://downloads.claude.ai/claude-science/latest/mac-x64.dmg).
Windows is not supported. 

## What it does

- **Installs the daemon for you** — the `.deb`/`.rpm` post-install hook downloads
  Claude Science (~152 MB) from Anthropic and verifies its SHA-256, so the app is
  ready the first time you open it. Failing that, the app fetches it on first run.
  An existing `claude-science` on your `PATH` is used as-is, and
  `CLAUDE_SCIENCE_BIN` overrides everything.
- **Starts it and signs you in** — the daemon's login page is a one-click
  anti-prefetch form; the app requests a fresh single-use link and submits it, so
  you never click through a sign-in screen.
- **Keeps the session honest** — if a page comes back "signed out", it fetches
  another link and retries, twice, then leaves the button to you.
- **Stops what it started** — quitting shuts down the daemon this app launched;
  one you started in a terminal is left alone (**File → Quit (leave daemon
  running)** skips the shutdown).
- **Routes links sensibly** — the daemon's UI (port 8000) and its HTML previews
  (8001) stay in-app; everything else opens in your browser.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh -s -- --uninstall
```

Your Claude Science data in `~/.claude-science` is never touched by that.

## Build from source

```bash
npm install && npm run dist
```

Produces `.deb` and `.tar.gz` in `dist/`. `.rpm` and pacman need `rpmbuild` and
`bsdtar`, so CI builds those on tagged releases. For a dev
run against a local daemon copy:

```bash
npm run fetch-daemon && npm start
```

More detail lives in the [wiki](https://github.com/yuvalkolodkingal/claude-science-desktop/wiki).

## Caveats

- **x64 only** — Claude Science ships only a linux-x64 binary.
- **Linux only** — macOS has Anthropic's official app; Windows has no public
  daemon build to wrap.
- Startup takes ~10–15 s on a cold daemon (MCP connector warmup) behind a
  loading screen.

## License

MIT for the wrapper — see [LICENSE](LICENSE). Claude Science itself is
Anthropic's proprietary software under Anthropic's terms.
