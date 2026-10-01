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
- `Sources/IliadBar`: interfaccia menu bar e finestre. I file di questo target
  (tranne il guscio macOS: `IliadBarApp`, `MainWindowView`, `PanelView`,
  `BoxView`, `FilesView`) sono compilati anche dall'app iOS dietro
  `#if canImport(AppKit)` / `#if canImport(UIKit)`.
- `Sources/IliadBariOS`: guscio iOS (@main, TabView, deep link).
- `Sources/IliadBarWidget`: estensione WidgetKit (macOS via SPM, iOS via
  XcodeGen: la stessa sorgente è compilata dal target extension del
  progetto).
- `Sources/ibx`: CLI (solo desktop).
- `Tests`: fixture e test di contratto/decodifica.
- `Scripts`: packaging, audit e release.
- `project.yml`: specifica XcodeGen del progetto iOS (`IliadBariOS.xcodeproj`
  è generato e ignorato, come `.build`).

## iOS

Il progetto iOS si genera con `xcodegen` e si compila con
`Scripts/make-ios-app.sh` (vedi README). Le differenze che contano:

- **Firma**: sul simulatore non serve nulla; per dispositivo fisico e
  TestFlight imposta `DEVELOPMENT_TEAM` (variabile d'ambiente o Xcode) e
  registra l'App Group `group.it.ivansposato.iliadbar` nel profilo.
- **Rete locale**: `NSLocalNetworkUsageDescription`, `NSBonjourServices`
  (`_fbx-api._tcp`) e `NSAllowsLocalNetworking` vivono in `project.yml`
  (Info.plist generato). La box parla HTTP sulla LAN: senza l'esenzione ATS
  le chiamate non partono.
- **Convenzione**: ogni API macOS-only va dentro `#if canImport(AppKit)`
  con un ramo UIKit equivalente, così `swift build` continua a validare
  entrambe le piattaforme.

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
./Scripts/make-ios-app.sh --sim
```
