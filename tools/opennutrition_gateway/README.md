# OpenNutrition Remote Gateway

Gateway read-only per recuperare singoli alimenti senza scaricare il catalogo
sul dispositivo. Il servizio non interroga endpoint privati o non documentati
di OpenNutrition: serve esclusivamente un indice costruito dal dataset
ufficialmente scaricabile.

## Confine di fiducia

Il client Flutter non considera attendibile il trasporto da solo. Ogni risposta
utile deve essere JSON, entro 256 KiB, associata al request ID, temporalmente
valida e firmata Ed25519. La chiave privata resta sul gateway; nell'APK entra
soltanto la chiave pubblica.

La firma protegge integrità e provenienza dei record anche in presenza di DNS,
proxy o CA compromessi, ma non impedisce denial of service. TLS, rate limiting,
CDN/WAF e disponibilità restano livelli separati.


## Livelli di astrazione della sicurezza

La ricerca è divisa in livelli indipendenti, ciascuno fail-closed:

1. **Query policy**: valida l'input originale prima della normalizzazione,
   rifiutando controlli, caratteri bidi, URL, delimitatori e pattern da
   injection; impone limiti distinti su caratteri, byte UTF-8, parole e
   lunghezza dei singoli termini.
2. **Gateway configuration policy**: accetta soltanto HTTPS sulla porta 443,
   hostname DNS pubblici ASCII, nessun IP letterale, userinfo, query,
   fragment o host locale.
3. **Transport policy**: solo `GET`, nessun redirect, timeout breve,
   concorrenza limitata, content type JSON e corpo massimo di 256 KiB.
4. **Authenticity policy**: ogni body è firmato Ed25519; key ID, request ID,
   timestamp, scadenza e replay vengono verificati prima del parsing dei dati.
5. **Schema policy**: campi sconosciuti, JSON troppo profondo, stringhe con
   controlli, identificativi ambigui e nutrienti fuori intervallo vengono
   rifiutati.
6. **Storage policy**: SQLite è immutabile e read-only, le query sono
   parametrizzate e l'espressione FTS viene prodotta esclusivamente dal
   server.
7. **Dataset ingestion policy**: checksum obbligatorio, limiti ZIP/TSV,
   controllo schema, rapporti massimi di record invalidi e pubblicazione
   atomica del database.

Nessun singolo livello è considerato sufficiente da solo. In particolare una
API key incorporata nell'APK non viene trattata come segreto.

## Difese applicate

1. database SQLite montato in sola lettura, non scrivibile e aperto con
   `mode=ro&immutable=1`;
2. sole richieste `GET`/`HEAD`, nessun body e nessun URL arbitrario recuperato
   dal server;
3. allowlist Host obbligatoria e rifiuto di host/IP locali;
4. header count/size, request target e clock skew limitati;
5. request ID monouso con replay cache limitata;
6. rate limit per IP/installazione con struttura LRU limitata;
7. limite di concorrenza e timeout SQLite tramite progress handler;
8. query normalizzate, token FTS prodotti dal server e SQL parametrizzato;
9. paginazione massima di 20 pagine e 20 risultati;
10. risposte JSON canoniche firmate Ed25519, con scadenza e key ID;
11. errori generici senza SQL, path, stack trace o dati interni;
12. HSTS, CSP deny-all, `nosniff`, no-store e frame denial;
13. container non-root, filesystem read-only, capability rimosse, limiti di
    CPU, RAM e PID;
14. nessun access log contenente le query;
15. import offline con SHA-256 obbligatorio, protezioni ZIP-slip, symlink,
    decompression bomb, field bomb, row limit, header duplicati, record
    duplicati, schema SQLite con `CHECK`, integrity check, FTS integrity check e
    pubblicazione atomica;
16. immagini remote disattivate per impostazione predefinita nel client. Possono
    essere abilitate soltanto con un dart-define esplicito e restano limitate a
    host HTTPS consentiti.

Il rate limit in memoria è soltanto un livello locale. In produzione è
obbligatorio aggiungere un limite distribuito sul reverse proxy o CDN. Una API
key statica nell'app non è un segreto e non va usata come protezione primaria.

## Generazione chiavi

```bash
python - <<'PY'
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

key = Ed25519PrivateKey.generate()
seed = key.private_bytes(
    serialization.Encoding.Raw,
    serialization.PrivateFormat.Raw,
    serialization.NoEncryption(),
)
public = key.public_key().public_bytes(
    serialization.Encoding.Raw,
    serialization.PublicFormat.Raw,
)
print("PRIVATE_SEED_BASE64=" + base64.b64encode(seed).decode())
print("PUBLIC_KEY_BASE64=" + base64.b64encode(public).decode())
PY
```

Preferire un secret file leggibile soltanto dall'utente del container:

```bash
install -m 0400 private-seed-base64.txt /run/secrets/opennutrition_signing_key
```

Configurare quindi:

```text
OPENNUTRITION_SIGNING_KEY_FILE=/run/secrets/opennutrition_signing_key
```

La variabile `OPENNUTRITION_SIGNING_KEY_BASE64` resta disponibile per ambienti
di sviluppo, ma è meno sicura perché può comparire nell'ambiente del processo.

## Configurazione Flutter

Compilare URL, chiave pubblica e key ID nella release:

```powershell
flutter run `
  --dart-define=OPENNUTRITION_GATEWAY_URL=https://nutrition.example.com `
  --dart-define=OPENNUTRITION_GATEWAY_ED25519_PUBLIC_KEY=<BASE64> `
  --dart-define=OPENNUTRITION_GATEWAY_KEY_ID=primary
```

La configurazione runtime è disponibile in debug. In release è bloccata, salvo
abilitazione deliberata tramite:

```text
--dart-define=OPENNUTRITION_ALLOW_CUSTOM_GATEWAY=true
```

Le immagini dei record remoti sono disattivate per default. L'opt-in richiede:

```text
--dart-define=OPENNUTRITION_GATEWAY_ALLOW_REMOTE_IMAGES=true
```

## Creazione del database

Scaricare manualmente il pacchetto ufficiale e il relativo SHA-256. Il tool non
accetta URL e non può essere trasformato in un vettore SSRF.

```bash
python import_dataset.py \
  --zip ./opennutrition-dataset.zip \
  --sha256 <SHA256_UFFICIALE> \
  --dataset-version 2026-07 \
  --output ./data/opennutrition.db
```

Il tool:

- rifiuta archivi simbolici, path traversal e ZIP anomali;
- richiede un solo TSV e intestazioni univoche;
- limita righe, campi, dimensioni e rapporto di compressione;
- normalizza Unicode e rimuove caratteri di controllo/formattazione;
- limita nutrienti a intervalli plausibili;
- verifica rapporto di righe invalide e duplicati;
- costruisce il database nello stesso filesystem della destinazione;
- verifica database e indice FTS;
- esegue `fsync`, `chmod 0444` e sostituzione atomica.


## Verifiche di sicurezza

```bash
python security_self_test.py
python self_test_importer.py
```

Nel progetto Flutter:

```powershell
flutter test `
  test/features/nutrition/open_nutrition_gateway_security_test.dart `
  test/features/nutrition/open_nutrition_gateway_signed_response_test.dart
```

Queste verifiche coprono configurazione host, policy query, firma valida,
firma di un attaccante, campi schema inattesi, scadenza delle risposte e
importazione difensiva del dataset.

## Avvio

```bash
cp .env.example .env
docker compose up --build
```

La porta è esposta soltanto su `127.0.0.1`. Il container deve stare dietro un
reverse proxy HTTPS che:

- sovrascriva `X-Forwarded-For` e non inoltri valori arbitrari del client;
- usi un IP fisso presente in `OPENNUTRITION_TRUSTED_PROXY_IPS`;
- imponga TLS moderno, HSTS e limiti di connessione;
- applichi rate limiting distribuito per IP;
- limiti request line, header e tempo di lettura;
- non registri query complete, barcode o installation ID;
- disabiliti buffering e upload illimitati;
- non esponga mai direttamente la porta 8080.

## Rotazione chiavi

Pubblicare prima una release dell'app con la nuova chiave pubblica. Durante la
finestra di rotazione mantenere due endpoint o due versioni dell'app, poi
rimuovere la vecchia chiave privata. Una chiave sospettata di compromissione va
revocata immediatamente e il gateway va disattivato finché una nuova release
non distribuisce la chiave pubblica sostitutiva.

## Incident response

In caso di abuso o compromissione:

1. disabilitare il DNS o il route del gateway;
2. ruotare la chiave privata;
3. rigenerare il database da archivio e checksum ufficiali;
4. invalidare cache CDN/WAF;
5. analizzare metriche aggregate, senza conservare query alimentari;
6. pubblicare una nuova release se cambia la chiave pubblica;
7. lasciare nell'app il fallback Open Food Facts e il catalogo locale.
