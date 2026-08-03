#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

AUDIT_DIR=$(mktemp -d /tmp/iliadbar-l10n-audit.XXXXXX)
trap 'rm -rf "$AUDIT_DIR"' EXIT
LOCALIZATION_SOURCES=(Sources/IliadBar/*.swift Sources/IliadBarWidget/*.swift Sources/IliadboxKit/FbxResponse.swift)

xcrun extractLocStrings -SwiftUI -u -littleEndian -o "$AUDIT_DIR" "${LOCALIZATION_SOURCES[@]}" >/dev/null 2>&1
plutil -lint Resources/Localization/en.lproj/Localizable.strings Resources/Localization/it.lproj/Localizable.strings >/dev/null
plutil -convert json -o "$AUDIT_DIR/extracted.json" "$AUDIT_DIR/Localizable.strings"
jq -r 'keys[]' "$AUDIT_DIR/extracted.json" | sort > "$AUDIT_DIR/extracted.keys"

# extractLocStrings currently misses some SwiftUI overloads (notably Button and
# Picker inside Menu/Toolbar builders). Add literal-only keys from the common
# user-visible initializers; interpolated strings remain handled by the Apple
# extractor so their positional placeholders are preserved correctly.
rg --pcre2 --no-filename -o --replace '$1' \
  '(?:Text|Label|Button|Toggle|Picker|Menu|navigationTitle|accessibilityLabel|ContentUnavailableView|TextField|confirmationDialog|appString|fbxLocalized|NSLocalizedString)\(\s*"((?:[^"\\]|\\.)*)"' \
  "${LOCALIZATION_SOURCES[@]}" \
  | rg -v '\\\(' \
  | sort -u > "$AUDIT_DIR/swiftui-literals.keys"
cat "$AUDIT_DIR/extracted.keys" "$AUDIT_DIR/swiftui-literals.keys" \
  | sort -u > "$AUDIT_DIR/required.keys"

for LOCALE in en it; do
  plutil -convert json -o "$AUDIT_DIR/$LOCALE.json" "Resources/Localization/$LOCALE.lproj/Localizable.strings"
  jq -r 'keys[]' "$AUDIT_DIR/$LOCALE.json" | sort > "$AUDIT_DIR/$LOCALE.keys"
  if MISSING=$(comm -23 "$AUDIT_DIR/required.keys" "$AUDIT_DIR/$LOCALE.keys") && [[ -n "$MISSING" ]]; then
    echo "Stringhe mancanti per $LOCALE:" >&2
    echo "$MISSING" >&2
    exit 1
  fi
done

echo "Localizzazione OK: tutte le stringhe SwiftUI estratte sono catalogate in it/en."
