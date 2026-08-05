# Notice — what this project is, and what it is not

**Claude Science Desktop is an unofficial, community-built wrapper.** It is not
affiliated with, endorsed by, sponsored by, or supported by Anthropic PBC.

## Trademarks

"Claude", "Claude Science" and "Anthropic" are trademarks of Anthropic PBC. They
are used here only nominatively — to state, truthfully, which program this
wrapper opens. This project claims no rights in them, does not use Anthropic's
logo, icon or artwork, and ships its own distinct icon.

If Anthropic would prefer a different name or presentation, open an issue and it
will be changed.

## What is distributed here

This repository and its release artifacts contain **only** the wrapper: an
Electron main process (`main.js`), a loading screen, an icon generator, install
scripts and packaging metadata. All of it is MIT-licensed.

**No Anthropic code or binary is redistributed.** The `claude-science` daemon is:

- downloaded by the app itself, at first run, directly from
  `https://downloads.claude.ai/claude-science/<version>/linux-x64`;
- verified against the SHA-256 checksum Anthropic publishes at
  `https://downloads.claude.ai/claude-science/latest/manifest.json` before it is
  ever executed;
- stored under the user's own data directory, never inside a package.

The Flatpak manifest uses Flatpak's `extra-data` mechanism, which records only a
URL, size and checksum — the download happens on the user's machine at install
time.

Your use of Claude Science is governed by Anthropic's terms, not by this
project's license.

## Support

Bugs in **this wrapper** — window behavior, packaging, install scripts — belong
in this repository's issue tracker.

Bugs in **Claude Science itself** are Anthropic's; please do not send them here,
and do not report wrapper problems to Anthropic as if they were product bugs.
