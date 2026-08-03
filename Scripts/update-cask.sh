#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' Sources/IliadboxKit/BuildInfo.swift)
ARCHIVE="build/IliadBar-$VERSION.zip"
if [[ ! -f "$ARCHIVE" ]]; then
  echo "Archivio non trovato: $ARCHIVE" >&2
  exit 1
fi
SHA256=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')

sed \
  -e "s/^  version .*/  version \"$VERSION\"/" \
  -e "s/^  sha256 .*/  sha256 \"$SHA256\"/" \
  -e "s#^  url .*#  url \"https://github.com/giveme11us/IliadBar/releases/download/v$VERSION/IliadBar-$VERSION.zip\"#" \
  Casks/iliadbar.rb > build/iliadbar.rb
mv build/iliadbar.rb Casks/iliadbar.rb

echo "Cask aggiornata per IliadBar $VERSION ($SHA256)"
