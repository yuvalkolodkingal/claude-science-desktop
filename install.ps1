# Claude Science Desktop installer (Windows) — unofficial wrapper.
#
# PowerShell:
#   irm https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.ps1 | iex
#
# cmd.exe:
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.ps1 | iex"
#
# Installs per-user into %LOCALAPPDATA%; no admin rights needed.
# Uninstall:  & ([scriptblock]::Create((irm <url>))) -Uninstall
#
# This installs the wrapper only. Claude Science itself is Anthropic's and is
# downloaded by the app from downloads.claude.ai on first run, verified against
# Anthropic's published checksum.

[CmdletBinding()]
param(
  [switch]$Uninstall,
  [string]$Version = $env:CSD_VERSION
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo     = 'yuvalkolodkingal/claude-science-desktop'
$AppId    = 'claude-science-desktop'
$AppName  = 'Claude Science Desktop'
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\ClaudeScienceDesktop"
$StartMenu  = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$AppName.lnk"
$DesktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "$AppName.lnk"

function Write-Step($msg) { Write-Host $msg }
function Fail($msg) { Write-Error $msg; exit 1 }

function Remove-Install {
  if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
    Write-Step "Removed $InstallDir"
  }
  foreach ($lnk in @($StartMenu, $DesktopLnk)) {
    if (Test-Path $lnk) { Remove-Item -Force $lnk }
  }
  Write-Step ''
  Write-Step 'Claude Science itself was not touched. To remove it too:'
  Write-Step '  claude-science stop'
  Write-Step "  Remove-Item -Recurse -Force `"$env:USERPROFILE\.claude-science`""
  exit 0
}

if ($Uninstall) { Remove-Install }

if ([Environment]::Is64BitOperatingSystem -eq $false) { Fail 'Windows x64 is required.' }
$arch = 'x64'

# --- resolve version --------------------------------------------------------

# Version-free asset names keep /releases/latest/download/<asset> valid forever,
# so the installer never touches the rate-limited GitHub API.
$asset = "$AppId-win-$arch.zip"
$base  =
  if ($env:CSD_BASE_URL) { $env:CSD_BASE_URL }
  elseif ($Version)      { "https://github.com/$Repo/releases/download/$Version" }
  else                   { "https://github.com/$Repo/releases/latest/download" }
$tmp   = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
  Write-Step "$AppName (win-$arch)"
  Write-Step "  downloading $asset"
  $zip = Join-Path $tmp $asset
  Invoke-WebRequest -Uri "$base/$asset" -OutFile $zip -UseBasicParsing

  # --- verify against the release checksums ---------------------------------
  $sumsFile = Join-Path $tmp 'SHA256SUMS'
  Invoke-WebRequest -Uri "$base/SHA256SUMS" -OutFile $sumsFile -UseBasicParsing
  $line = Get-Content $sumsFile | Where-Object { $_ -match [regex]::Escape($asset) } | Select-Object -First 1
  if (-not $line) { Fail "$asset is missing from SHA256SUMS" }
  $expected = ($line -split '\s+')[0]
  $actual = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $expected.ToLower()) {
    Fail "Checksum mismatch for ${asset}:`n  expected $expected`n  got      $actual"
  }
  Write-Step "  verified sha256 $actual"

  # --- install --------------------------------------------------------------
  if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
  New-Item -ItemType Directory -Path $InstallDir | Out-Null
  Expand-Archive -Path $zip -DestinationPath $InstallDir -Force

  $exe = Get-ChildItem -Path $InstallDir -Filter '*.exe' -Recurse |
         Where-Object { $_.Name -notmatch 'unins|crashpad|setup' } |
         Select-Object -First 1
  if (-not $exe) { Fail 'No executable found in the release archive.' }

  $shell = New-Object -ComObject WScript.Shell
  foreach ($lnk in @($StartMenu, $DesktopLnk)) {
    $sc = $shell.CreateShortcut($lnk)
    $sc.TargetPath = $exe.FullName
    $sc.WorkingDirectory = $exe.DirectoryName
    $sc.Description = "Unofficial desktop window for Claude Science"
    $sc.Save()
  }

  Write-Step ''
  Write-Step "Installed $AppName"
  Write-Step "  app      $InstallDir"
  Write-Step "  shortcut Start Menu and Desktop"
  Write-Step ''
  Write-Step 'This build is unsigned, so SmartScreen may warn on first launch:'
  Write-Step '  More info -> Run anyway.'
  Write-Step ''
  Write-Step 'Unofficial wrapper - not affiliated with Anthropic.'
  Write-Step 'Claude Science downloads on first launch from downloads.claude.ai.'
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
