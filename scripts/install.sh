#!/bin/bash
set -euo pipefail
OWNER="alexkkork"
REPO="GmailDesktop"
ASSET="GmailDesktop.app.zip"
TMP="$(mktemp -d)"

# Fetch latest release asset URL via GitHub API (no auth needed for public repo)
LATEST_URL=$(curl -fsSL "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" | \
  ruby -r json -e 'j=JSON.parse(STDIN.read); a=j["assets"].find{|x| x["name"]=="GmailDesktop.app.zip"}; puts a ? a["browser_download_url"] : ""')

if [ -z "$LATEST_URL" ]; then
  echo "Could not find latest release asset. Falling back to v0.2.0" >&2
  LATEST_URL="https://github.com/${OWNER}/${REPO}/releases/download/v0.2.0/${ASSET}"
fi

cd "$TMP"
echo "Downloading $LATEST_URL" >&2
curl -fL "$LATEST_URL" -o "$ASSET"
unzip -q "$ASSET"

# Remove any existing installs (quit first if running)
echo "Cleaning up previous installs..." >&2
osascript -e 'tell application "GmailDesktop" to quit' >/dev/null 2>&1 || true
rm -rf "/Applications/GmailDesktop.app" "$HOME/Applications/GmailDesktop.app" 2>/dev/null || true

# Install to /Applications if writable, otherwise to ~/Applications
DEST="/Applications"
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi
echo "Installing to $DEST" >&2
rm -rf "$DEST/GmailDesktop.app"
cp -R "GmailDesktop.app" "$DEST/"

echo "Launching app..." >&2
open "$DEST/GmailDesktop.app"
