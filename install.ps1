# QuickPatch CLI installer for Windows (PowerShell).
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/letssuhail/quickpatch/main/install.ps1 | iex
#
# Mirrors install.sh but for Windows: downloads the windows-x64 binary, clones
# the QuickPatch Flutter fork, and wires up a wrapper + PATH.

$ErrorActionPreference = "Stop"

$Repo = "letssuhail/quickpatch-cli"
$BinName = "quickpatch"
$QuickPatchHome = if ($env:QUICKPATCH_HOME) { $env:QUICKPATCH_HOME } else { Join-Path $env:USERPROFILE ".quickpatch" }

$OsKey = "windows"
$ArchKey = "x64"

Write-Host "Installing QuickPatch CLI..."
Write-Host "  OS:   $OsKey"
Write-Host "  Arch: $ArchKey"

# Git is required to fetch the QuickPatch Flutter fork. Fail early with a clear
# message rather than midway through the install.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git is required but was not found. Install Git for Windows from https://git-scm.com/download/win, then re-run this installer."
  exit 1
}

# Resolve the latest release tag.
$latest = (Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest").tag_name
if (-not $latest) { Write-Error "Could not determine latest release."; exit 1 }

$asset = "$BinName-$OsKey-$ArchKey.zip"
$url = "https://github.com/$Repo/releases/download/$latest/$asset"
$extractedExe = "$BinName-$OsKey-$ArchKey.exe"

Write-Host "  Version: $latest"
Write-Host "  Downloading $asset..."

$tmp = Join-Path $env:TEMP ("qp-" + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
  $zipPath = Join-Path $tmp $asset
  # Start-BitsTransfer shows a native progress bar with size/speed/ETA. Fall
  # back to Invoke-WebRequest if BITS isn't available.
  try {
    Start-BitsTransfer -Source $url -Destination $zipPath -Description "Downloading QuickPatch CLI"
  } catch {
    $ProgressPreference = "Continue"
    Invoke-WebRequest -Uri $url -OutFile $zipPath
  }
  Expand-Archive -Path $zipPath -DestinationPath $tmp -Force

  # Place the real binary 3 levels deep so quickpatchRoot resolves to
  # QUICKPATCH_HOME\bin (binary lives at bin\cache\quickpatch.exe).
  $cacheDir = Join-Path $QuickPatchHome "bin\cache"
  New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
  Copy-Item -Path (Join-Path $tmp $extractedExe) -Destination (Join-Path $cacheDir "$BinName.exe") -Force

  # Pinned Flutter fork (= Flutter 3.44.0). Engine artifacts come from R2 at build time.
  $flutterRev = "1a55eb72b61a6c8acac0bf7f7d4738f399f83a0f"
  $flutterBranch = "flutter_release/3.44.0"
  $flutterRepo = "https://github.com/shorebirdtech/flutter.git"

  $internalDir = Join-Path $QuickPatchHome "bin\internal"
  New-Item -ItemType Directory -Force -Path $internalDir | Out-Null
  Set-Content -Path (Join-Path $internalDir "flutter.version") -Value $flutterRev -NoNewline

  $flutterDir = Join-Path $QuickPatchHome "bin\cache\flutter\$flutterRev"
  if (-not (Test-Path (Join-Path $flutterDir "bin"))) {
    Write-Host ""
    Write-Host "  Downloading QuickPatch Flutter (one-time, ~1GB)."
    Write-Host "  This can take 3-15 minutes depending on your connection. Please wait..."
    if (Test-Path $flutterDir) { Remove-Item -Recurse -Force $flutterDir }

    # Windows defaults to a 260-char path limit, which Flutter's deeply nested
    # engine test fixtures exceed ("Filename too long"). Clone WITHOUT a
    # checkout, enable git long-path support on the repo, then check out. This
    # keeps the full SDK intact and just removes the path-length limit.
    git clone --progress --no-checkout --branch $flutterBranch $flutterRepo $flutterDir
    Push-Location $flutterDir
    try {
      git config core.longpaths true
      git checkout $flutterBranch
    } finally {
      Pop-Location
    }
  }

  # Wrapper .bat at bin\quickpatch.bat that sets QUICKPATCH_ROOT and runs the exe.
  $binDir = Join-Path $QuickPatchHome "bin"
  New-Item -ItemType Directory -Force -Path $binDir | Out-Null
  $wrapper = @"
@echo off
set "QUICKPATCH_ROOT=%USERPROFILE%\.quickpatch"
"%USERPROFILE%\.quickpatch\bin\cache\$BinName.exe" %*
"@
  Set-Content -Path (Join-Path $binDir "$BinName.bat") -Value $wrapper

  # Add bin dir to the user PATH (persisted) if not already present.
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
  }

  Write-Host ""
  Write-Host "Installed: $binDir\$BinName.bat"
  Write-Host ""
  Write-Host "Open a NEW terminal, then run: quickpatch --version"
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
