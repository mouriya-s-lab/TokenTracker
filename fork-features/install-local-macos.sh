#!/usr/bin/env bash
# Installs this checkout's runtime into the local /Applications/TokenTracker.app
# and the global npm CLI. The Swift shell stays as installed (no Xcode needed);
# only Contents/Resources/EmbeddedServer is rebuilt from this checkout.
#
# The app must not be managed by the Homebrew cask, and its in-app silent
# auto-update must stay off, or either replaces the patched runtime.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP=/Applications/TokenTracker.app
EMBED_SRC="$REPO/TokenTrackerBar/EmbeddedServer"
ENTITLEMENTS="$REPO/TokenTrackerBar/TokenTrackerBar/TokenTrackerBar.entitlements"

[[ -d "$APP" ]] || { echo "missing $APP" >&2; exit 1; }
if brew list --cask tokentracker >/dev/null 2>&1; then
  echo "Homebrew still manages the tokentracker cask; detach it first" >&2
  exit 1
fi
defaults write com.tokentracker.bar UpdateChecker.autoUpdateEnabled -bool false

cd "$REPO"
npm --prefix dashboard ci --silent
npm run dashboard:build
TokenTrackerBar/scripts/bundle-node.sh --arch arm64

osascript -e 'quit app "TokenTracker"' || true
while pgrep -f "$APP/Contents/MacOS/" >/dev/null; do sleep 1; done

STAGE="$(mktemp -d /tmp/tt-embedded-old.XXXX)"
mv "$APP/Contents/Resources/EmbeddedServer" "$STAGE/EmbeddedServer"
ditto "$EMBED_SRC" "$APP/Contents/Resources/EmbeddedServer"
codesign --force --sign - "$APP/Contents/Resources/EmbeddedServer/node"
codesign --force --timestamp=none --entitlements "$ENTITLEMENTS" --sign - "$APP"
codesign --verify --verbose=2 "$APP"
echo "previous EmbeddedServer kept at $STAGE"

PACK="$(mktemp -d /tmp/tt-pack.XXXX)"
npm pack --pack-destination "$PACK" --silent
npm install -g "$PACK"/tokentracker-cli-*.tgz

open -a "$APP"
