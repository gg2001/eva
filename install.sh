#!/usr/bin/env bash
#
# Installs eva from the latest (or specified) GitHub release.
#
#   curl -L https://raw.githubusercontent.com/gg2001/eva/main/install.sh | bash          # latest
#   EVA_VERSION=v0.0.1 curl -L … | bash                                                  # pinned
#
set -euo pipefail

REPO="gg2001/eva"
VERSION="${EVA_VERSION:-latest}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# ─── Detect platform ────────────────────────────────────────────────────────────
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  linux)   os_id=linux ;;
  darwin)  os_id=darwin ;;
  *) echo "❌ unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64) arch_id=amd64 ;;
  arm64|aarch64) arch_id=arm64 ;;
  *) echo "❌ unsupported arch: $ARCH"; exit 1 ;;
esac

TARGET="${os_id}_${arch_id}"             # e.g. linux_amd64, darwin_arm64
ASSET="eva_${VERSION}_${TARGET}.tar.gz"  # matches release naming

# ─── Resolve release JSON and asset URL ────────────────────────────────────────
if [[ "$VERSION" == "latest" ]]; then
  api="https://api.github.com/repos/$REPO/releases/latest"
else
  api="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
fi

echo "➜ Fetching release info ($api)…"

url=$(
  curl -fsSL "$api" |
    grep -oE '"browser_download_url":[[:space:]]*"[^"]*'"${TARGET}"'\.tar\.gz"' |
    head -n1 |
    cut -d'"' -f4
)

if [[ -z "$url" ]]; then
  echo "❌ no binary for $TARGET in release $VERSION"
  exit 1
fi

# Get asset name from URL
asset_name=$(basename "$url")
ASSET="${asset_name}"
echo "Asset file: ${ASSET}"

# Download the release asset
echo "➜ Downloading ${ASSET}…"
curl -# -L "$url" -o "${TMPDIR}/${ASSET}"

# ─── Unpack binary ─────────────────────────────────────────────────────────────
tar -xzf "$TMPDIR/$ASSET" -C "$TMPDIR"
# Find the binary in a cross-platform way
BIN_PATH=""
for f in "$TMPDIR"/*; do
  if [ -f "$f" ] && [ -x "$f" ]; then
    BIN_PATH="$f"
    break
  fi
done
[[ -z "$BIN_PATH" ]] && { echo "❌ binary not found in archive"; exit 1; }

# ─── Choose install dir ────────────────────────────────────────────────────────
INSTALL_DIR=${INSTALL_DIR:-/usr/local/bin}
if [[ ! -w "$INSTALL_DIR" ]]; then
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
  PATH="$INSTALL_DIR:$PATH"
  echo "ℹ️  Installing to $INSTALL_DIR (add it to \$PATH if needed)"
fi

install -m 0755 "$BIN_PATH" "$INSTALL_DIR/eva"
echo "✅ eva installed to $INSTALL_DIR/eva"

# ─── Test run ──────────────────────────────────────────────────────────────────
echo
# "$INSTALL_DIR/eva" --help 2>&1 | head -n 20 || true
