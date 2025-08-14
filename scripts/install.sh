#!/bin/bash
set -euo pipefail
OWNER="alexkkork"
REPO="GmailDesktop"
TAG="v0.1.0"
ASSET="GmailDesktop.app.zip"
TMP="$(mktemp -d)"
URL="https://github.com/${OWNER}/${REPO}/releases/download/${TAG}/${ASSET}"
cd "$TMP"
echo "Downloading $URL" >&2
curl -L "$URL" -o "$ASSET"
unzip -q "$ASSET"
echo "Opening app..." >&2
open "GmailDesktop.app"
