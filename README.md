<div align="center">

# ⚡ QuickPatch

**Ship Flutter updates over the air — in seconds, not weeks.**

Push Dart code changes straight to your users' devices. No App Store review for code fixes.

[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Windows-10b981)](#install-the-cli)

</div>

---

QuickPatch is a code-push system for Flutter. After you ship a build to the
stores once, you can push **Dart code updates over the air** — bug fixes, UI
tweaks, new screens — and your users get them on the next launch. No re-review,
no reinstall.

## Install the CLI

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/letssuhail/quickpatch/main/install.sh | bash
```

**Windows** (PowerShell)

```powershell
irm https://raw.githubusercontent.com/letssuhail/quickpatch/main/install.ps1 | iex
```

> Requires [git](https://git-scm.com/downloads). The first install downloads the
> QuickPatch Flutter (~1 GB), so it can take a few minutes. Open a **new**
> terminal afterwards, then run `quickpatch --version`.

## Quick start

**macOS / Linux**

```bash
# Point the CLI at your server (get a token from your QuickPatch dashboard)
export QUICKPATCH_HOSTED_URL="https://your-server.example.com"
export QUICKPATCH_TOKEN="qp_api_..."

# In your Flutter project
quickpatch init
quickpatch release android        # build + publish; upload to the store as usual
quickpatch patch android --release-version=1.0.0+1   # ship a Dart change over the air
```

**Windows** (PowerShell)

```powershell
$env:QUICKPATCH_HOSTED_URL = "https://your-server.example.com"
$env:QUICKPATCH_TOKEN = "qp_api_..."

quickpatch init
quickpatch release android
quickpatch patch android --release-version=1.0.0+1
```

Your users' apps check for the patch on launch and apply it on the next one.

## Platform support

| Platform | Build Android | Build iOS |
| --- | --- | --- |
| macOS | ✅ | ✅ |
| Linux | ✅ | — |
| Windows | ✅ | — |

iOS releases require macOS (Apple's toolchain). Android works everywhere.

## What can be patched?

| ✅ Works as a patch | ❌ Needs a full release |
| --- | --- |
| Dart logic & bug fixes | New Flutter plugins |
| UI changes, new screens | Native code (Kotlin / Swift) |
| Text, colors, styling | New bundled assets / fonts |

## Project repositories

| Repo | Description |
| --- | --- |
| [quickpatch](https://github.com/letssuhail/quickpatch) | Installers + docs (this repo) |
| [quickpatch-cli](https://github.com/letssuhail/quickpatch-cli) | The `quickpatch` command-line tool |
