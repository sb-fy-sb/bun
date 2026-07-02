#!/bin/sh
# Bun for HarmonyOS (OHOS) — Quick Install Script
#
# Usage:
#   curl -fsSL https://ghfast.top/https://github.com/sb-fy-sb/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh
#
# Or without proxy:
#   curl -fsSL https://github.com/sb-fy-sb/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh
#
# Install directory: ~/usr/bun/bin/bun
#
set -eu

REPO="sb-fy-sb/bun"
RELEASE_TAG="ohos-latest"
BINARY_NAME="bun-ohos-aarch64"
INSTALL_DIR="$HOME/usr/bun"
INSTALL_BIN="$INSTALL_DIR/bin/bun"
PROXY="${BUN_INSTALL_PROXY:-https://ghfast.top/}"

# Colors (if terminal supports them)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; exit 1; }

# --- Pre-flight checks ---

info "Bun OHOS Installer"
info "==================="

# Check architecture
ARCH=$(uname -m)
case "$ARCH" in
  aarch64|arm64)
    ok "Architecture: $ARCH"
    ;;
  *)
    error "Unsupported architecture: $ARCH (requires aarch64/arm64)"
    ;;
esac

# Check OS
OS=$(uname -s)
case "$OS" in
  Linux)
    ok "Operating System: Linux"
    ;;
  *)
    error "Unsupported OS: $OS (requires Linux)"
    ;;
esac

# Check curl or wget
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
else
  error "Neither curl nor wget found. Install one of them first."
fi
ok "Downloader: $DOWNLOADER"

# --- Download ---

DOWNLOAD_URL="${PROXY}https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}"
TMP_FILE=$(mktemp /tmp/bun-ohos-XXXXXX)

info "Downloading bun from:"
info "  $DOWNLOAD_URL"

if [ "$DOWNLOADER" = "curl" ]; then
  HTTP_CODE=$(curl -fsSL -w '%{http_code}' -o "$TMP_FILE" "$DOWNLOAD_URL" 2>/dev/null) || {
    # Try without proxy
    warn "Proxy download failed, trying direct..."
    HTTP_CODE=$(curl -fsSL -w '%{http_code}' -o "$TMP_FILE" \
      "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}" 2>/dev/null) || \
      error "Download failed (HTTP $HTTP_CODE). Check your network."
  }
else
  wget -q -O "$TMP_FILE" "$DOWNLOAD_URL" 2>/dev/null || {
    warn "Proxy download failed, trying direct..."
    wget -q -O "$TMP_FILE" \
      "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}" 2>/dev/null || \
      error "Download failed. Check your network."
  }
  HTTP_CODE=200
fi

# Verify download
if [ ! -s "$TMP_FILE" ]; then
  rm -f "$TMP_FILE"
  error "Downloaded file is empty"
fi

FILE_SIZE=$(wc -c < "$TMP_FILE" | tr -d ' ')
if [ "$FILE_SIZE" -lt 1000000 ]; then
  rm -f "$TMP_FILE"
  error "Downloaded file too small (${FILE_SIZE} bytes), likely corrupted"
fi

ok "Downloaded $((FILE_SIZE / 1048576)) MB"

# --- Install ---

# Create install directory
mkdir -p "$INSTALL_DIR/bin"

# Remove old binary if exists
if [ -f "$INSTALL_BIN" ]; then
  info "Removing old bun at $INSTALL_BIN"
  rm -f "$INSTALL_BIN"
fi

# Move binary
mv "$TMP_FILE" "$INSTALL_BIN"
chmod +x "$INSTALL_BIN"
ok "Installed to $INSTALL_BIN"

# --- PATH setup ---

BIN_DIR="$INSTALL_DIR/bin"
PROFILE=""

# Find the right shell profile
if [ -n "${BASH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "bash" ]; then
  [ -f "$HOME/.bashrc" ] && PROFILE="$HOME/.bashrc"
  [ -f "$HOME/.bash_profile" ] && PROFILE="$HOME/.bash_profile"
elif [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
  [ -f "$HOME/.zshrc" ] && PROFILE="$HOME/.zshrc"
fi

# Also check .profile as fallback
[ -z "$PROFILE" ] && [ -f "$HOME/.profile" ] && PROFILE="$HOME/.profile"

PATH_LINE="export PATH=\"$BIN_DIR:\$PATH\""

if [ -n "$PROFILE" ]; then
  if ! grep -qF "$BIN_DIR" "$PROFILE" 2>/dev/null; then
    echo "" >> "$PROFILE"
    echo "# Bun OHOS" >> "$PROFILE"
    echo "$PATH_LINE" >> "$PROFILE"
    ok "Added $BIN_DIR to PATH in $PROFILE"
  else
    ok "$BIN_DIR already in PATH ($PROFILE)"
  fi
else
  warn "Could not find shell profile. Add this to your shell config manually:"
  warn "  $PATH_LINE"
fi

# Export PATH for current session
export PATH="$BIN_DIR:$PATH"

# --- Verify ---

info "Verifying installation..."
if [ -x "$INSTALL_BIN" ]; then
  VERSION=$("$INSTALL_BIN" --version 2>/dev/null || echo "unknown")
  ok "bun $VERSION installed successfully!"
else
  warn "Binary installed but may need signing for OHOS execution"
  warn "Run: binary-sign-tool sign -inFile \"$INSTALL_BIN\" -outFile \"$INSTALL_BIN\" -selfSign 1"
fi

echo ""
echo "  bun is installed at: $INSTALL_BIN"
echo ""
echo "  To get started:"
echo "    export PATH=\"$BIN_DIR:\$PATH\""
echo "    bun --version"
echo ""
