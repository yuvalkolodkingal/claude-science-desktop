# Claude Science Desktop

An **unofficial** desktop window for [Claude Science](https://claude.com/product/claude-science).
It starts the local `claude-science` daemon, signs you in, and renders its web UI
in a native window instead of a browser tab.

> Not affiliated with, endorsed by, or supported by Anthropic. "Claude" and
> "Claude Science" are trademarks of Anthropic PBC, used here only to say what
> this wrapper opens.

## Pages

- **[Installation](Installation)** — one-liners, per-distro packages, Flatpak, portable, Windows, macOS
- **[How it works](How-it-works)** — daemon lifecycle, sign-in, link routing
- **[Building from source](Building-from-source)** — local builds and CI
- **[Uninstalling](Uninstalling)** — removing the wrapper without touching your data
- **[FAQ](FAQ)** — signing warnings, ports, troubleshooting

## The 30-second version

```bash
curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh
```

Pick native / Flatpak / portable when prompted, launch **Claude Science Desktop**
from your app menu, and wait ~10–15 s on first run while the daemon warms up.

## What is not shipped here

No Anthropic code. The `claude-science` binary is downloaded by the app from
`downloads.claude.ai` at first run and checked against the SHA-256 Anthropic
publishes in `latest/manifest.json` before it is executed. The Flatpak does the
same through Flatpak's `extra-data` mechanism, at install time.
