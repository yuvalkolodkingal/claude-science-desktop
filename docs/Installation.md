# Installation

This wrapper is **Linux-only** — see the bottom of this page for macOS.

Every download is verified against `SHA256SUMS` from the same release before it
is installed. Linux builds are **x64 only**, because Claude Science itself ships
only a linux-x64 binary.

## One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh
```

On Linux it detects your distro and asks how you want it installed:

| Mode | What it does | Needs sudo |
| --- | --- | --- |
| **Native** | `.deb` via apt, `.rpm` via dnf/zypper, or pacman package | yes |
| **Portable** | unpacks into `~/.local/share/claude-science-desktop` + a menu entry | no |

Skip the prompt:

```bash
curl -fsSL .../install.sh | sh -s -- --native
curl -fsSL .../install.sh | sh -s -- --portable
```

Useful environment variables:

- `CSD_VERSION=v0.1.0` — install a specific release instead of the latest
- `CSD_PREFIX=~/.local` — where a portable install lands
- `CSD_BASE_URL=…` — install from a local directory or mirror of the assets


## Manual downloads

From [Releases](https://github.com/yuvalkolodkingal/claude-science-desktop/releases/latest):

| File | For |
| --- | --- |
| `claude-science-desktop-linux-amd64.deb` | Debian, Ubuntu, Mint, Pop!_OS |
| `claude-science-desktop-linux-x86_64.rpm` | Fedora, RHEL, openSUSE |
| `claude-science-desktop-linux-x64.pacman` | Arch, Manjaro, EndeavourOS |
| `claude-science-desktop-linux-x64.tar.gz` | portable / other |

Because the filenames carry no version, this link always points at the newest
build:

```
https://github.com/yuvalkolodkingal/claude-science-desktop/releases/latest/download/claude-science-desktop-linux-amd64.deb
```

There is deliberately **no Flatpak**: Claude Science sandboxes its agent with
bubblewrap, which cannot create its nested user namespace inside a Flatpak
sandbox. Use the portable install on distros without a native package.

## Arch (AUR-style build)

A [PKGBUILD](https://github.com/yuvalkolodkingal/claude-science-desktop/blob/main/aur/PKGBUILD)
lives in `aur/`. Run `updpkgsums` to fill in the checksums, then `makepkg -si`.

## First launch

The app has no Claude Science binary bundled. On first run it downloads the
official build (~152 MB) from `downloads.claude.ai`, verifies its SHA-256
against Anthropic's manifest, and stores it under your user data directory. If
you already have `claude-science` on your `PATH`, that one is used instead —
`CLAUDE_SCIENCE_BIN=/path/to/claude-science` overrides everything.

## macOS and Windows

**macOS**: use Anthropic's official app — signed, notarized, and maintained by
them: [mac-arm64.dmg](https://downloads.claude.ai/claude-science/latest/mac-arm64.dmg)
(Apple Silicon) or [mac-x64.dmg](https://downloads.claude.ai/claude-science/latest/mac-x64.dmg)
(Intel). This wrapper would only be a worse, unsigned version of it.

**Windows**: not supported. Anthropic publishes no downloadable Windows build of
the daemon, so there is nothing for a wrapper to run.
