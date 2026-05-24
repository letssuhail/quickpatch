#!/usr/bin/env bash
set -euo pipefail

# QuickPatch CLI installer
# Usage: curl -fsSL https://raw.githubusercontent.com/letssuhail/quickpatch/main/install.sh | bash

REPO="letssuhail/quickpatch-cli"
BIN_NAME="quickpatch"
QUICKPATCH_HOME="${QUICKPATCH_HOME:-$HOME/.quickpatch}"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux)  OS_KEY="linux" ;;
  Darwin) OS_KEY="macos" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64)  ARCH_KEY="x64" ;;
  arm64|aarch64) ARCH_KEY="arm64" ;;
  *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "Installing QuickPatch CLI..."
echo "  OS:   $OS_KEY"
echo "  Arch: $ARCH_KEY"

# git is required to fetch the QuickPatch Flutter fork.
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but was not found. Install git and re-run."
  exit 1
fi

LATEST=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')

if [ -z "$LATEST" ]; then
  echo "Could not determine latest release."
  exit 1
fi

ASSET="${BIN_NAME}-${OS_KEY}-${ARCH_KEY}.tar.gz"
URL="https://github.com/$REPO/releases/download/$LATEST/$ASSET"
EXTRACTED_NAME="${BIN_NAME}-${OS_KEY}-${ARCH_KEY}"

echo "  Version: $LATEST"
echo "  Downloading $ASSET..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# -fL: fail on HTTP errors + follow redirects. --progress-bar shows a download
# progress bar (instead of -s which hides it) so the user sees activity.
curl -fL --progress-bar "$URL" -o "$TMP_DIR/$ASSET"
tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR"

# Place the actual binary 3 levels deep so quickpatchRoot resolves to
# QUICKPATCH_HOME/bin (binary lives at bin/cache/quickpatch).
CACHE_DIR="$QUICKPATCH_HOME/bin/cache"
mkdir -p "$CACHE_DIR"
cp "$TMP_DIR/$EXTRACTED_NAME" "$CACHE_DIR/$BIN_NAME"
chmod +x "$CACHE_DIR/$BIN_NAME"

# These are pinned to the Shorebird v1.6.105 engine artifacts on GCS.
# flutter.version = Shorebird's flutter fork revision (= Flutter 3.44.0)
QUICKPATCH_FLUTTER_REV="1a55eb72b61a6c8acac0bf7f7d4738f399f83a0f"
QUICKPATCH_FLUTTER_BRANCH="flutter_release/3.44.0"
QUICKPATCH_FLUTTER_REPO="https://github.com/shorebirdtech/flutter.git"

# Write internal version files that the CLI reads at startup.
INTERNAL_DIR="$QUICKPATCH_HOME/bin/internal"
mkdir -p "$INTERNAL_DIR"
echo "$QUICKPATCH_FLUTTER_REV" > "$INTERNAL_DIR/flutter.version"

# Clone QuickPatch's (Shorebird) Flutter fork. This is the patchable Flutter
# the CLI uses to build releases and resolve the Flutter version via git.
# Engine artifacts are fetched from our R2 mirror at build time.
FLUTTER_DIR="$QUICKPATCH_HOME/bin/cache/flutter/$QUICKPATCH_FLUTTER_REV"
if [ ! -d "$FLUTTER_DIR/.git" ]; then
  echo ""
  echo "  Downloading QuickPatch Flutter (one-time, ~1GB)."
  echo "  This can take 3-15 minutes depending on your connection. Please wait..."
  rm -rf "$FLUTTER_DIR"
  # --progress forces git to print receiving/resolving percentages even when
  # stdout is piped (as it is with `curl ... | bash`).
  git clone --progress --branch "$QUICKPATCH_FLUTTER_BRANCH" \
    "$QUICKPATCH_FLUTTER_REPO" "$FLUTTER_DIR"
fi

# Write a thin wrapper script at ~/.quickpatch/bin/quickpatch that sets
# QUICKPATCH_ROOT so the binary resolves paths correctly.
WRAPPER_DIR="$QUICKPATCH_HOME/bin"
mkdir -p "$WRAPPER_DIR"
cat > "$WRAPPER_DIR/$BIN_NAME" <<WRAPPER
#!/usr/bin/env bash
export QUICKPATCH_ROOT="\$HOME/.quickpatch"
exec "\$HOME/.quickpatch/bin/cache/$BIN_NAME" "\$@"
WRAPPER
chmod +x "$WRAPPER_DIR/$BIN_NAME"

echo ""
echo "Installed: $WRAPPER_DIR/$BIN_NAME"

SHELL_RC=""
case "$SHELL" in
  */zsh)  SHELL_RC="$HOME/.zshrc" ;;
  */bash) SHELL_RC="$HOME/.bashrc" ;;
esac

if [ -n "$SHELL_RC" ]; then
  if ! grep -qF '.quickpatch/bin' "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# QuickPatch CLI" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/.quickpatch/bin:\$PATH\"" >> "$SHELL_RC"
  fi
fi

echo ""
echo "Run: source ~/.zshrc (or open a new terminal)"
echo "Then: quickpatch --version"
