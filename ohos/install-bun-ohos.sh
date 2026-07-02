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
INSTALL_DIR="$HOME/usr/bin"
INSTALL_BIN="$INSTALL_DIR/bun"
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
  Linux|HarmonyOS)
    ok "Operating System: $OS"
    ;;
  *)
    error "Unsupported OS: $OS (requires Linux or HarmonyOS)"
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

# Create install directory first, download directly to target
mkdir -p "$INSTALL_DIR"
rm -f "$INSTALL_BIN"

info "Downloading bun from:"
info "  $DOWNLOAD_URL"

if [ "$DOWNLOADER" = "curl" ]; then
  curl -fsSL -o "$INSTALL_BIN" "$DOWNLOAD_URL" 2>/dev/null || {
    warn "Proxy download failed, trying direct..."
    curl -fsSL -o "$INSTALL_BIN" \
      "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}" 2>/dev/null || \
      error "Download failed. Check your network."
  }
else
  wget -q -O "$INSTALL_BIN" "$DOWNLOAD_URL" 2>/dev/null || {
    warn "Proxy download failed, trying direct..."
    wget -q -O "$INSTALL_BIN" \
      "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}" 2>/dev/null || \
      error "Download failed. Check your network."
  }
fi

# Verify download
if [ ! -s "$INSTALL_BIN" ]; then
  rm -f "$INSTALL_BIN"
  error "Downloaded file is empty"
fi

FILE_SIZE=$(wc -c < "$INSTALL_BIN" | tr -d ' ')
if [ "$FILE_SIZE" -lt 1000000 ]; then
  rm -f "$INSTALL_BIN"
  error "Downloaded file too small (${FILE_SIZE} bytes), likely corrupted"
fi

ok "Downloaded $((FILE_SIZE / 1048576)) MB"

# --- Install ---

chmod +x "$INSTALL_BIN"
ok "Installed to $INSTALL_BIN"

# --- PATH setup ---

BIN_DIR="$INSTALL_DIR"
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

# --- Verify & Sign ---

info "Verifying installation..."
if [ -x "$INSTALL_BIN" ]; then
  # Try to auto-sign if binary-sign-tool is available (OHOS device only)
  SIGN_TOOL=""
  for p in \
    "/system/bin/binary-sign-tool" \
    "/usr/bin/binary-sign-tool" \
    "$(command -v binary-sign-tool 2>/dev/null)"; do
    if [ -n "$p" ] && [ -x "$p" ]; then SIGN_TOOL="$p"; break; fi
  done

  if [ -n "$SIGN_TOOL" ]; then
    info "Signing binary with $SIGN_TOOL..."
    SIGNED="${INSTALL_BIN}.signed"
    rm -f "$SIGNED"
    "$SIGN_TOOL" sign -inFile "$INSTALL_BIN" -outFile "$SIGNED" -selfSign 1 2>/dev/null && {
      mv -f "$SIGNED" "$INSTALL_BIN"
      chmod +x "$INSTALL_BIN"
      ok "Binary signed successfully"
    } || {
      rm -f "$SIGNED"
      warn "Auto-signing failed, you may need to sign manually:"
      warn "  binary-sign-tool sign -inFile \"$INSTALL_BIN\" -outFile \"$INSTALL_BIN\" -selfSign 1"
    }
  else
    warn "binary-sign-tool not found (not on OHOS device?)"
    warn "To run bun on OHOS, sign it first:"
    warn "  binary-sign-tool sign -inFile \"$INSTALL_BIN\" -outFile \"$INSTALL_BIN\" -selfSign 1"
  fi

  VERSION=$("$INSTALL_BIN" --version 2>/dev/null || echo "unknown (may need signing)")
  ok "bun $VERSION installed successfully!"
else
  error "Installation failed: binary not found at $INSTALL_BIN"
fi

echo ""
echo "  bun is installed at: $INSTALL_BIN"
echo ""
echo "  To get started:"
echo "    export PATH=\"$BIN_DIR:\$PATH\""
echo "    bun --version"
echo ""
