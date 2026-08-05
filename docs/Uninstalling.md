# Uninstalling

## Linux and macOS

```bash
curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh -s -- --uninstall
```

It removes whichever forms it finds — Flatpak, `.deb`, `.rpm`, pacman package,
portable install, or the macOS `.app` — and cleans up the menu entry and icon.

By hand:

```bash
sudo apt remove claude-science-desktop          # Debian / Ubuntu
sudo dnf remove claude-science-desktop          # Fedora
sudo pacman -R claude-science-desktop           # Arch
flatpak uninstall io.github.yuvalkolodkingal.ClaudeScienceDesktop
rm -rf ~/.local/share/claude-science-desktop    # portable
rm -rf ~/Applications/"Claude Science Desktop.app"
```

## Windows

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.ps1))) -Uninstall
```

Or, if you used the `.exe` installer, uninstall it from **Settings → Apps**.

## What survives on purpose

Uninstalling the wrapper never touches:

- `~/.claude-science` — your Claude Science data directory
- the `claude-science` binary itself, wherever it lives

To remove those too:

```bash
claude-science stop
rm -rf ~/.claude-science
```

And the app's own managed copy of the daemon plus wrapper settings:

```bash
rm -rf ~/.config/"Claude Science Desktop"
```
