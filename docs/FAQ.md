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

### Why is there no Flatpak?

Because Claude Science cannot run inside one. It sandboxes its agent with
**bubblewrap** and refuses to start without `bwrap` on `PATH` — that sandbox is
what stops the agent from having full `$HOME` read/write and unrestricted
network. Creating the nested user namespace bwrap needs is blocked inside a
Flatpak sandbox, and stays blocked even with `--allow=devel`. The only way to
make it run would be `--dangerously-no-sandbox`, which removes exactly the
protection Anthropic built in — so this project does not ship a Flatpak.

On distros without a native package, use the portable install
(`sh -s -- --portable`); it needs no root and works anywhere.

Flathub was never an option either: its requirements reject thin wrappers and
simple web wrappers, its Generative AI policy forbids applications containing
AI-generated or AI-assisted code, and its trademark rules forbid a wrapper
carrying the wrapped product's name.

### How do I get updates?

Re-run the install one-liner; it always fetches the latest release. Claude
Science updates itself separately, on its own schedule.
