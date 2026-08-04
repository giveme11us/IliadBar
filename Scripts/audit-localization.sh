#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

AUDIT_DIR=$(mktemp -d /tmp/iliadbar-l10n-audit.XXXXXX)
trap 'rm -rf "$AUDIT_DIR"' EXIT
LOCALIZATION_SOURCES=(Sources/IliadBar/*.swift Sources/IliadBarWidget/*.swift Sources/IliadboxKit/FbxResponse.swift)

# Letterali che finiscono in un ternario ma non sono testo per l'utente:
# valori logici, nomi di simboli SF senza punto, sigle di protocollo.
# Aggiungerne di nuovi solo dopo aver verificato che non finiscano a schermo.
NON_UI_LITERALS='^(true|false|yes|no|nopass|HTTP|HTTPS|WPA|WEP|circle|magnifyingglass|100%)$'

xcrun extractLocStrings -SwiftUI -u -littleEndian -o "$AUDIT_DIR" "${LOCALIZATION_SOURCES[@]}" >/dev/null 2>&1
plutil -lint Resources/Localization/en.lproj/Localizable.strings Resources/Localization/it.lproj/Localizable.strings >/dev/null
plutil -convert json -o "$AUDIT_DIR/extracted.json" "$AUDIT_DIR/Localizable.strings"
jq -r 'keys[]' "$AUDIT_DIR/extracted.json" | sort > "$AUDIT_DIR/extracted.keys"

# extractLocStrings currently misses some SwiftUI overloads (notably Button and
# Picker inside Menu/Toolbar builders). Add literal-only keys from the common
# user-visible initializers; interpolated strings remain handled by the Apple
# extractor so their positional placeholders are preserved correctly.
# perl instead of ripgrep: the CI runner does not ship rg.
# Tre famiglie: inizializzatori SwiftUI e helper di localizzazione; argomenti
# etichettati title:/label: dei componenti interni (che prendono
# LocalizedStringKey — `Text(String)` non localizzerebbe); primo argomento
# posizionale dei nostri helper di card.
perl -nle '
  while (/(?:Text|Label|Button|Toggle|Picker|Menu|navigationTitle|accessibilityLabel|ContentUnavailableView|TextField|confirmationDialog|appString|fbxLocalized|NSLocalizedString|serviceCard|permissionRow|metric|help)\(\s*"((?:[^"\\]|\\.)*)"/g) {
    print $1;
  }
  while (/\b(?:title|label):\s*"((?:[^"\\]|\\.)*)"/g) {
    print $1;
  }
  while (/String\(localized:\s*"((?:[^"\\]|\\.)*)"/g) {
    print $1;
  }
  # Testo scelto con un ternario ("attivo" : "disattivo"): sfugge a ogni
  # estrattore basato sul nome dell inizializzatore.
  while (/\?\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"/g) {
    print $1;
    print $2;
  }
' "${LOCALIZATION_SOURCES[@]}" \
  | grep -vF '\(' \
  | grep -vE '^[a-z0-9]+(\.[a-z0-9]+)+$' \
  | grep -vE "$NON_UI_LITERALS" \
  | sort -u > "$AUDIT_DIR/swiftui-literals.keys"
cat "$AUDIT_DIR/extracted.keys" "$AUDIT_DIR/swiftui-literals.keys" \
  | sort -u > "$AUDIT_DIR/required.keys"

AUDIT_FAILED=0
for LOCALE in en it; do
  plutil -convert json -o "$AUDIT_DIR/$LOCALE.json" "Resources/Localization/$LOCALE.lproj/Localizable.strings"
  jq -r 'keys[]' "$AUDIT_DIR/$LOCALE.json" | sort > "$AUDIT_DIR/$LOCALE.keys"
  # Nessun early exit: si riportano tutte le lingue in una sola passata.
  if MISSING=$(comm -23 "$AUDIT_DIR/required.keys" "$AUDIT_DIR/$LOCALE.keys") && [[ -n "$MISSING" ]]; then
    echo "Stringhe mancanti per $LOCALE:" >&2
    echo "$MISSING" >&2
    AUDIT_FAILED=1
  fi
done
[[ "$AUDIT_FAILED" == "0" ]] || exit 1

echo "Localizzazione OK: tutte le stringhe SwiftUI estratte sono catalogate in it/en."
