# Claude Science Desktop

A desktop window for [Claude Science](https://claude.com/product/claude-science) —
it starts the local `claude-science` daemon, signs you in, and shows the UI in a
native window instead of a browser tab.

> **Unofficial.** Not affiliated with, endorsed by, or supported by Anthropic.
> No Anthropic code is redistributed here — the app downloads Claude Science from
> Anthropic's own servers on first run and verifies it against Anthropic's
> published checksum. See [NOTICE.md](NOTICE.md).

## Install

**Linux / macOS**

```bash
curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh
```

On Linux it detects your distro and offers a native package (`.deb`, `.rpm`,
pacman), a Flatpak, or a no-sudo portable install. Skip the prompt with
`| sh -s -- --native`, `--flatpak`, or `--portable`.

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.ps1 | iex
```

**Windows (cmd.exe)**

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.ps1 | iex"
```

Or grab a package directly from [Releases](https://github.com/yuvalkolodkingal/claude-science-desktop/releases/latest).

## What it does

- **Finds or fetches the daemon** — uses `CLAUDE_SCIENCE_BIN`, a Flatpak
  `extra-data` copy, `claude-science` on your `PATH`, or downloads the official
  build (~152 MB) on first run, refusing to run it unless the SHA-256 matches
  Anthropic's manifest.
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

Produces `.deb` and `.tar.gz` in `dist/`. `.rpm`, pacman and Flatpak builds need
`rpmbuild` / `flatpak-builder`, so CI builds those on tagged releases. For a dev
run against a local daemon copy:

```bash
npm run fetch-daemon && npm start
```

More detail lives in the [wiki](https://github.com/yuvalkolodkingal/claude-science-desktop/wiki).

## Caveats

- Linux builds are **x64 only**, because Claude Science ships only a linux-x64
  binary.
- macOS and Windows builds are **unsigned** — Gatekeeper and SmartScreen will
  warn on first launch. The install scripts tell you how to get past it.
- Startup takes ~10–15 s on a cold daemon (MCP connector warmup) behind a
  loading screen.

## License

MIT for the wrapper — see [LICENSE](LICENSE). Claude Science itself is
Anthropic's proprietary software under Anthropic's terms.
