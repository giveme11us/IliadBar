# Sicurezza

## Credenziali

Il token permanente ricevuto dalla box viene salvato nella configurazione locale,
separatamente per ogni profilo. Il file viene creato atomicamente con permessi
`0600`, quindi è leggibile soltanto dall'utente corrente. Le vecchie installazioni
possono importare una volta il token dal Portachiavi; la copia precedente non viene
cancellata automaticamente.

Le sessioni API sono temporanee. IliadBar firma la challenge della box in locale
e mantiene il token di sessione solo in memoria.

## Rete e TLS

La discovery avviene in LAN tramite Bonjour. IliadBar preferisce HTTPS quando
la box lo dichiara e limita l'eccezione App Transport Security alla rete locale.
Una configurazione manuale HTTP resta possibile per firmware compatibili che non
espongono HTTPS.

## Azioni amministrative

Le operazioni distruttive richiedono conferma e descrivono il loro effetto. I
controlli vengono disabilitati quando la sessione non espone il permesso
necessario. I range di porte vengono validati prima di inviare modifiche NAT.

## Aggiornamenti

Le release pubbliche devono essere firmate con Developer ID, hardened runtime,
notarizzate e verificate da Gatekeeper. Sparkle verifica inoltre ogni archivio
con una firma EdDSA. Le chiavi private e i certificati non appartengono al
repository e vengono forniti alla pipeline tramite secret.

Nelle build Developer ID l’App Group condiviso con il widget usa il formato
macOS `<Team ID>.it.ivansposato.iliadbar`; app, estensione, entitlements e
Info.plist vengono generati dalla stessa variabile per impedire divergenze.

## Segnalazioni

Non aprire issue pubbliche contenenti token, IP pubblici, MAC address, SSID o
diagnostica non revisionata. In assenza di un canale security dedicato, apri una
issue priva di dettagli sensibili chiedendo un contatto privato al maintainer.
