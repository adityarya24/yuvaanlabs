#!/bin/sh
# Hivelane installer for Linux and macOS (Apple silicon).
#   curl -fsSL https://yuvaanlabs.com/hivelane/install.sh | sh
# Re-run it to update. Your data and licence live in ~/.hivelane and are kept.
set -eu

BASE="${HIVELANE_DOWNLOAD_BASE:-https://yuvaanlabs.com/hivelane/download}"
APP_DIR="${HIVELANE_APP_DIR:-$HOME/.local/share/hivelane/app}"
BIN_DIR="${HIVELANE_BIN_DIR:-$HOME/.local/bin}"

say() { printf '%s\n' "$*"; }
die() { printf 'hivelane install: %s\n' "$*" >&2; exit 1; }

case "$(uname -s)/$(uname -m)" in
  Linux/x86_64|Linux/amd64) NAME="hivelane-linux-x64" ;;
  Darwin/arm64) NAME="hivelane-macos-arm64" ;;
  Darwin/*) die "on macOS only Apple silicon (M1 or newer) is supported for now." ;;
  Linux/*) die "only x86_64 Linux is supported for now (found $(uname -m))." ;;
  *) die "this installer is for Linux and macOS. On Windows use install.ps1." ;;
esac
command -v curl >/dev/null 2>&1 || die "curl is required."
command -v tar >/dev/null 2>&1 || die "tar is required."
# Older macOS has only shasum; macOS 26 has a BSD sha256sum without --status.
# Both print "<hash>  <file>", so the hash is compared as text.
if command -v sha256sum >/dev/null 2>&1; then SHA256="sha256sum"
elif command -v shasum >/dev/null 2>&1; then SHA256="shasum -a 256"
else die "sha256sum (or shasum) is required."; fi

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
GOT="$($SHA256 "$TMP/$NAME.tar.gz" | cut -d' ' -f1)"
[ "$GOT" = "$SUM" ] \
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
# New terminals must find the commands. ~/.profile alone is read only by
# login shells, so a GNOME terminal opened after installing said "command
# not found". Add one marked line to each startup file that exists (and
# ~/.profile), never twice.
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) PATH_LINE="export PATH=\"$BIN_DIR:\$PATH\"  # added by Hivelane"
     added=""
     # macOS terminals run zsh and read ~/.zprofile and ~/.zshrc, which a new
     # Mac may not have yet, so those two are created there.
     if [ "$(uname -s)" = "Darwin" ]; then RCS="$HOME/.zprofile $HOME/.zshrc $HOME/.bash_profile"; MUST="$HOME/.zprofile $HOME/.zshrc"
     else RCS="$HOME/.profile $HOME/.bashrc $HOME/.zshrc"; MUST="$HOME/.profile"; fi
     for rc in $RCS; do
       case " $MUST " in *" $rc "*) ;; *) [ -f "$rc" ] || continue ;; esac
       grep -qs "# added by Hivelane" "$rc" && continue
       printf '\n%s\n' "$PATH_LINE" >> "$rc" && added="$added ${rc#"$HOME"/}"
     done
     say ""
     if [ -n "$added" ]; then
       say "Added $BIN_DIR to your PATH in:$added. Open a new terminal to use 'hivelane'."
     else
       say "Open a new terminal to use 'hivelane'."
     fi ;;
esac

if [ "${HIVELANE_SKIP_SETUP:-}" != "1" ]; then
  say ""
  say "Connecting Hivelane to the agent CLIs on this machine..."
  "$BIN_DIR/hivelane" setup || say "Setup reported a problem. Run 'hivelane doctor' to see what is missing."
fi
say ""
if [ "${HIVELANE_UPDATING:-}" = "1" ]; then
  say "Done. Restart your agent sessions to use the new version."
else
  say "Done. Next: hivelane activate <your-licence-key>"
fi
