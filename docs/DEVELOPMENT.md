# Sviluppo

## Requisiti

- macOS 14+
- Swift 6 / Xcode Command Line Tools
- una iliadbox per gli smoke test reali; i test unitari non la richiedono

## Ciclo locale

```sh
swift package resolve
swift test
./Scripts/audit-localization.sh
./Scripts/make-app.sh
open build/IliadBar.app
```

`make-app.sh` produce un bundle completo con app, CLI, widget, localizzazioni,
icona e Sparkle. Senza `CODE_SIGN_IDENTITY` usa una firma ad-hoc adatta allo
sviluppo. Non eseguire mutazioni negli smoke test se la box non espone il
permesso `settings`.

`Scripts/runtime-smoke.sh` esegue installazione pulita, migrazione offline,
multi-box e token revocato usando directory di configurazione temporanee.
L'override `ILIADBAR_CONFIG_DIRECTORY` è riservato a test e automazione locale.

## Struttura

- `Sources/IliadboxKit`: logica condivisa e client API.
- `Sources/IliadBar`: interfaccia menu bar e finestre.
- `Sources/IliadBarWidget`: estensione WidgetKit.
- `Sources/ibx`: CLI.
- `Tests`: fixture e test di contratto/decodifica.
- `Scripts`: packaging, audit e release.

## Regole API

Non fissare una versione API in un nuovo endpoint: usa il client configurato dal
profilo scoperto. Tratta campi e moduli come capability variabili. Ogni mutazione
deve verificare permessi, validare l'input e avere una conferma UI se distruttiva.

Per aggiungere testo visibile, usa `String(localized:)` o `LocalizedStringKey` e
aggiorna entrambe le tabelle in `Resources/Localization`.

## Verifiche prima di una PR

```sh
swift format --in-place --recursive Sources Tests
swift test
./Scripts/audit-localization.sh
./Scripts/make-app.sh
codesign --verify --deep --strict build/IliadBar.app
```
