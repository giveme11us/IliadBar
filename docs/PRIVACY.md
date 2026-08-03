# Privacy

IliadBar comunica direttamente dal Mac alla iliadbox sulla rete locale. Non
possiede backend, account cloud, analytics o telemetria propri.

## Dati trattati

Per mostrare e amministrare la box, l'app può leggere indirizzi di rete, nomi e
MAC dei dispositivi, SSID, download, file, chiamate, contatti e configurazioni
dei servizi, in base ai permessi concessi. Questi dati restano sul Mac e sulla
box salvo un'azione esplicita dell'utente, come scaricare un file o aprire una
condivisione.

Il token della box è conservato nel file di configurazione privato (`0600`).
WidgetKit riceve soltanto uno snapshot minimale senza token, URL della box, IP,
MAC, nomi di dispositivi o chiavi Wi-Fi.

## Diagnostica

L'esportazione diagnostica omette token e sessioni e redige URL, host, IP, MAC,
nomi e credenziali Wi-Fi. Prima di condividere un file diagnostico è comunque
consigliato controllarne il contenuto.

Sparkle contatta esclusivamente il feed pubblico degli aggiornamenti e GitHub
per scaricare una release quando il controllo aggiornamenti è attivo.
