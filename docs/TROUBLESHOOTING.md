# Risoluzione dei problemi

## La box non viene trovata

- Verifica che Mac e iliadbox siano sulla stessa rete locale e senza isolamento
  client/guest.
- Concedi a IliadBar il permesso **Rete locale** in Impostazioni di Sistema.
- Disattiva temporaneamente VPN o firewall che bloccano Bonjour/mDNS.
- Usa la configurazione manuale nelle impostazioni se il firmware non pubblica
  `_fbx-api._tcp`.

## Associazione o sessione non riuscita

L'associazione va confermata fisicamente sulla box. Se il token è stato revocato,
rimuovi il profilo dall'app, associalo nuovamente e concedi solo i permessi
necessari. Verifica che il file `~/Library/Application Support/IliadBar/config.json`
appartenga al tuo utente e abbia permessi `0600`.

## Informazioni mancanti o controlli disabilitati

Le API cambiano tra modelli e firmware. IliadBar mostra solo i moduli dichiarati
dalla box e rende espliciti permessi mancanti o endpoint non supportati. Una box
con permesso `settings` disabilitato resta intenzionalmente in sola lettura.

## Stato non aggiornato

L'indicatore mostra se i dati sono live, ottenuti via polling, stale o offline.
Puoi modificare la frequenza nelle impostazioni e forzare un refresh con
`⌘R`.

## La build da sorgente non trova Sparkle

Esegui `swift package resolve` e riprova. Sparkle è un artefatto binario; proxy o
filtri aziendali possono impedire a SwiftPM di scaricarlo anche quando GitHub è
raggiungibile dal browser.

## Diagnostica

Apri **Impostazioni → Diagnostica**, esporta il JSON redatto e controllalo prima
di allegarlo a una segnalazione. Non condividere mai token o chiavi private.
