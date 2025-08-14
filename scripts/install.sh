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
echo "Opening app..." >&2
open "GmailDesktop.app"
