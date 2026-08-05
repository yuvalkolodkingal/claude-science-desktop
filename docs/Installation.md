# Installation

Every download is verified against `SHA256SUMS` from the same release before it
is installed. Linux builds are **x64 only**, because Claude Science itself ships
only a linux-x64 binary.

## Linux and macOS — one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh
```

On Linux it detects your distro and asks how you want it installed:

| Mode | What it does | Needs sudo |
| --- | --- | --- |
| **Native** | `.deb` via apt, `.rpm` via dnf/zypper, or pacman package | yes |
| **Flatpak** | per-user Flatpak bundle, sandboxed, any distro | no |
| **Portable** | unpacks into `~/.local/share/claude-science-desktop` + a menu entry | no |

Skip the prompt:

```bash
curl -fsSL .../install.sh | sh -s -- --native
curl -fsSL .../install.sh | sh -s -- --flatpak
curl -fsSL .../install.sh | sh -s -- --portable
```

Useful environment variables:

- `CSD_VERSION=v0.1.0` — install a specific release instead of the latest
- `CSD_PREFIX=~/.local` — where a portable install lands
- `CSD_BASE_URL=…` — install from a local directory or mirror of the assets

## Windows

PowerShell:

```powershell
irm https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.ps1 | iex
```

cmd.exe:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.ps1 | iex"
```

It installs per-user into `%LOCALAPPDATA%\Programs\ClaudeScienceDesktop` and adds
Start Menu and Desktop shortcuts. No admin rights required. The build is
unsigned, so SmartScreen shows "Windows protected your PC" on first launch —
**More info → Run anyway**.

## Manual downloads

From [Releases](https://github.com/yuvalkolodkingal/claude-science-desktop/releases/latest):

| File | For |
| --- | --- |
| `claude-science-desktop-linux-amd64.deb` | Debian, Ubuntu, Mint, Pop!_OS |
| `claude-science-desktop-linux-x86_64.rpm` | Fedora, RHEL, openSUSE |
| `claude-science-desktop-linux-x64.pacman` | Arch, Manjaro, EndeavourOS |
| `claude-science-desktop-x86_64.flatpak` | any distro with Flatpak |
| `claude-science-desktop-linux-x64.tar.gz` | portable / other |
| `claude-science-desktop-mac-arm64.zip` | Apple Silicon |
| `claude-science-desktop-mac-x64.zip` | Intel Macs |
| `claude-science-desktop-win-x64-setup.exe` | Windows installer |
| `claude-science-desktop-win-x64.zip` | Windows portable |

Because the filenames carry no version, this link always points at the newest
build:

```
https://github.com/yuvalkolodkingal/claude-science-desktop/releases/latest/download/claude-science-desktop-linux-amd64.deb
```

Install a Flatpak bundle by hand:

```bash
flatpak install --user ./claude-science-desktop-x86_64.flatpak
```

## Arch (AUR-style build)

A [PKGBUILD](https://github.com/yuvalkolodkingal/claude-science-desktop/blob/main/aur/PKGBUILD)
lives in `aur/`. Run `updpkgsums` to fill in the checksums, then `makepkg -si`.

## First launch

The app has no Claude Science binary bundled. On first run it downloads the
official build (~152 MB) from `downloads.claude.ai`, verifies its SHA-256
against Anthropic's manifest, and stores it under your user data directory. If
you already have `claude-science` on your `PATH`, that one is used instead —
`CLAUDE_SCIENCE_BIN=/path/to/claude-science` overrides everything.
