#!/bin/sh
# Hivelane installer for Linux.
#   curl -fsSL https://yuvaanlabs.com/hivelane/install.sh | sh
# Re-run it to update. Your data and licence live in ~/.hivelane and are kept.
set -eu

BASE="${HIVELANE_DOWNLOAD_BASE:-https://yuvaanlabs.com/hivelane/download}"
APP_DIR="${HIVELANE_APP_DIR:-$HOME/.local/share/hivelane/app}"
BIN_DIR="${HIVELANE_BIN_DIR:-$HOME/.local/bin}"

say() { printf '%s\n' "$*"; }
die() { printf 'hivelane install: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || die "this installer is for Linux. On Windows use install.ps1; macOS is in beta."
case "$(uname -m)" in
  x86_64|amd64) ARCH=x64 ;;
  *) die "only x86_64 Linux is supported for now (found $(uname -m))." ;;
esac
NAME="hivelane-linux-$ARCH"
command -v curl >/dev/null 2>&1 || die "curl is required."
command -v tar >/dev/null 2>&1 || die "tar is required."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# The site's CDN can serve an old copy for a few minutes after a release.
# Fetch the checksums uncached, then ask for the archive by its hash so both
# come from the same release.
curl -fsSL "$BASE/SHA256SUMS?t=$(date +%s)" -o "$TMP/SHA256SUMS"
SUM="$(grep " \*\{0,1\}$NAME.tar.gz\$" "$TMP/SHA256SUMS" | cut -d' ' -f1)"
[ -n "$SUM" ] || die "no checksum published for $NAME.tar.gz. Nothing was installed."
say "Downloading Hivelane ($NAME)..."
curl -fSL --progress-bar "$BASE/$NAME.tar.gz?sha256=$SUM" -o "$TMP/$NAME.tar.gz"
printf '%s  %s\n' "$SUM" "$TMP/$NAME.tar.gz" | sha256sum -c --status \
  || die "checksum mismatch: the download is damaged or was changed. Nothing was installed."

tar -xzf "$TMP/$NAME.tar.gz" -C "$TMP"
[ -x "$TMP/$NAME/hivelane.bin" ] || die "archive is missing hivelane.bin."

# Swap in the new version in one step, keeping the old one until it works.
mkdir -p "$(dirname "$APP_DIR")" "$BIN_DIR"
rm -rf "$APP_DIR.new" "$APP_DIR.old"
mv "$TMP/$NAME" "$APP_DIR.new"
"$APP_DIR.new/hivelane.bin" --selftest >/dev/null 2>&1 || die "the new build failed its self-test. Nothing was changed."
[ -d "$APP_DIR" ] && mv "$APP_DIR" "$APP_DIR.old"
mv "$APP_DIR.new" "$APP_DIR"
rm -rf "$APP_DIR.old"

# Command names. Nuitka reads the real binary name through symlinks, so each
# command is a tiny shim that tells the binary which part to run.
shim() {
  printf '#!/bin/sh\nexec "%s/hivelane.bin"%s "$@"\n' "$APP_DIR" "$2" > "$BIN_DIR/$1"
  chmod 755 "$BIN_DIR/$1"
}
shim hivelane ""
shim hivelane-dispatch " -m hivelane.dispatch.cli"
shim hivelane-codex-hook " -m hivelane.codex_hook"
shim hivelane-claude-hook " -m hivelane.claude_hook"

say "Installed to $APP_DIR"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say ""
     say "Add $BIN_DIR to your PATH, then open a new terminal:"
     say "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.profile" ;;
esac

if [ "${HIVELANE_SKIP_SETUP:-}" != "1" ]; then
  say ""
  say "Connecting Hivelane to the agent CLIs on this machine..."
  "$BIN_DIR/hivelane" setup || say "Setup reported a problem. Run 'hivelane doctor' to see what is missing."
fi
say ""
say "Done. Next: hivelane activate <your-licence-key>"
