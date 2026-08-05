# FAQ

### Is this made by Anthropic?

No. It is an unofficial, community-built wrapper, not affiliated with, endorsed
by, or supported by Anthropic. Bugs in the window, packaging or installers belong
here; bugs in Claude Science itself are Anthropic's.

### Does it bundle Claude Science?

No — and that is deliberate. Bundling Anthropic's binary in a package we publish
would mean redistributing their proprietary software. Instead the `.deb`/`.rpm`
post-install hook downloads it **on your machine** from `downloads.claude.ai` and
verifies its SHA-256 against Anthropic's published manifest, so the app is ready
on first open. If that download fails, the app retries at first launch.

### Is there a macOS or Windows build?

macOS has an **official** Claude Science app from Anthropic — signed and
notarized — so this project does not ship one:
[mac-arm64.dmg](https://downloads.claude.ai/claude-science/latest/mac-arm64.dmg) ·
[mac-x64.dmg](https://downloads.claude.ai/claude-science/latest/mac-x64.dmg).

Windows is unsupported: Anthropic publishes no downloadable Windows daemon
build, so a wrapper would have nothing to run.

Linux is the gap this project fills — there is no official Linux desktop app,
only the daemon and its browser UI.

### It takes 10–15 seconds to start.

That is the daemon warming up its MCP connectors, not the window. The loading
screen tells you what it's doing. A daemon that is already running skips it.

### Why did it ask me to sign in — and then sign me in instantly?

It shouldn't anymore. The daemon's login link serves a one-click form (a gate so
prefetchers can't burn the single-use nonce); the app submits it for you. If you
see the button, the automatic submit was tried twice and gave up — click it, and
please file an issue.

### Can I use my existing `claude-science` install?

Yes. Anything on your `PATH` is preferred over the app's managed copy, and
`CLAUDE_SCIENCE_BIN=/path/to/claude-science` overrides everything.

### Does quitting kill my daemon?

Only if the app started it. A daemon you launched in a terminal survives.
**File → Quit (leave daemon running)** skips the shutdown entirely.

### Which ports does it use?

The daemon's defaults: `8000` for the UI and `8001` for generated HTML previews,
both on `127.0.0.1`. Change them by starting the daemon yourself with
`claude-science serve --port N`; the app will reuse it.

### Is there an ARM Linux build?

No. Claude Science ships only a `linux-x64` binary, so an ARM wrapper would have
nothing to run. macOS ARM is fine — Anthropic ships `darwin-arm64`.

### How does the Flatpak work?

Claude Science sandboxes its own agent with **bubblewrap**, and a Flatpak
sandbox cannot create the nested user namespace bwrap needs — so a fully
self-contained Flatpak is impossible. Instead the Flatpak runs only the Electron
UI in the sandbox and starts the daemon **on the host** through `flatpak-spawn`
(`--talk-name=org.freedesktop.Flatpak`), where its own sandbox works normally.

That means the Flatpak is a packaging convenience, not an extra security
boundary: the daemon has the same access it would have if you installed the
`.deb`. Its own bubblewrap sandbox still gates what the agent can touch.

Flathub is a separate matter — its requirements reject thin wrappers and simple
web wrappers, its Generative AI policy forbids applications containing
AI-generated or AI-assisted code, and its trademark rules forbid a wrapper
carrying the wrapped product's name. So the bundle is distributed straight from
GitHub Releases.

### How do I get updates?

Re-run the install one-liner; it always fetches the latest release. Claude
Science updates itself separately, on its own schedule.
