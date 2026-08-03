# Release

## Prerequisiti

- certificato `Developer ID Application` installato
- Team ID Apple disponibile come `DEVELOPMENT_TEAM`; viene usato per l’App Group
  macOS condiviso con il widget
- profilo `notarytool` salvato nel Portachiavi
- coppia EdDSA di Sparkle; la chiave privata non va mai nel repository
- versione aggiornata in `Sources/IliadboxKit/BuildInfo.swift`

## Release locale

```sh
export CODE_SIGN_IDENTITY='Developer ID Application: …'
export DEVELOPMENT_TEAM='XXXXXXXXXX'
export SPARKLE_PUBLIC_KEY='…'
export SPARKLE_PRIVATE_KEY='…'
export NOTARY_PROFILE='iliadbar-notary'
./Scripts/release.sh
./Scripts/generate-appcast.sh
```

Lo script esegue test e audit, firma con hardened runtime, crea l'archivio,
invia la notarizzazione, applica lo staple, verifica Gatekeeper e produce lo
SHA-256. `generate-appcast.sh` passa la chiave privata a Sparkle via standard
input e non la scrive su disco. `NOTARY_PROFILE` è obbligatorio: lo script non
produce intenzionalmente una “release” non notarizzata.

## GitHub Actions

La workflow `release.yml` parte dai tag `v*`, importa temporaneamente il
certificato, costruisce/notarizza e pubblica gli artefatti. Richiede questi
repository secret:

- `DEVELOPER_ID_P12_BASE64`
- `DEVELOPER_ID_P12_PASSWORD`
- `CODE_SIGN_IDENTITY`
- `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` (`APPLE_TEAM_ID` alimenta
  anche `DEVELOPMENT_TEAM` durante il packaging)
- `SPARKLE_PUBLIC_KEY`, `SPARKLE_PRIVATE_KEY`

Il feed `appcast.xml` viene allegato alla GitHub Release ed è raggiunto tramite
`releases/latest/download/appcast.xml`; non richiede GitHub Pages. La Cask viene
generata con `Scripts/update-cask.sh` usando versione e SHA reali. Se esiste una
release precedente, la pipeline ne scarica archivio e appcast prima della
generazione per preservare lo storico e produrre gli eventuali delta Sparkle.

## Checklist candidata

- [ ] CI verde su commit pulito.
- [ ] Associazione nuova e migrazione da una versione precedente.
- [ ] Avvio offline, token revocato e cambio box gestiti correttamente.
- [ ] Smoke test in sola lettura e mutazioni autorizzate su box di test.
- [ ] Widget aggiornati senza dati sensibili.
- [ ] Archivio notarizzato, staple valido e Gatekeeper accettato su un Mac pulito.
- [ ] Aggiornamento Sparkle dalla release precedente completato.
- [ ] Changelog, appcast, GitHub Release e Cask corrispondono alla stessa versione.
