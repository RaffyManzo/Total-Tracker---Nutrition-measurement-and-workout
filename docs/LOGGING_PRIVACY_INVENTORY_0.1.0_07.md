# Inventario logging e privacy — 0.1.0-07 refinement

## Confine applicato

`DiagnosticPrivacy` viene applicato prima della serializzazione JSON. Le stringhe sono negate per impostazione predefinita: restano in chiaro soltanto identificatori tecnici e codici enum presenti in una allowlist ristretta. Sono rimossi o ridotti:

- nomi e note;
- valori corporei, calorie, macro, passi, sonno e frequenza cardiaca;
- carichi e ripetizioni;
- query e testo di ricerca;
- percorsi e cartelle completi;
- messaggi liberi delle eccezioni, ridotti al solo tipo runtime;
- percorsi completi incorporati negli stack trace.

Restano ammessi:

- identificatori causali generati dall'app;
- hash non reversibili già previsti per UUID sorgente;
- codici evento;
- date logiche `YYYY-MM-DD` necessarie al debug;
- durate, conteggi, revisioni e stati;
- versione app, build e schema.

## Eventi refinement

| Evento | Dati ammessi |
|---|---|
| `pubsub.food.publish` | eventId, operationId, tipo, data logica, revisione, conteggi |
| `pubsub.food.subscriber` | identificatore tecnico sanitizzato, durata coda, skip |
| `pubsub.target_input.publish` | hash UUID, range date, motivo, metriche |
| `pubsub.target_recalculation.*` | range, conteggi, durate, correlazione |
| `lifecycle.*` | stato, generazione, backgroundMs, coda e subscriber misurati |

## Regole

1. Nessun nome di persona o alimento libero viene richiesto per la diagnostica; anche i campi `message`, `title`, `label`, `description` e `text` vengono oscurati.
2. Nessuna nota, peso, composizione corporea, calorie, macro, passi, sonno, frequenza cardiaca, carico o ripetizione deve essere loggata in chiaro.
3. Nessun percorso filesystem completo deve uscire nel JSONL.
4. La chiave diagnostica viene rinominata in `objectBoxModelSchemaVersion`: identifica la versione dello schema/modello generato, non la versione runtime della libreria ObjectBox.
5. Non vengono registrati contatori fissi per timer o overlay come se fossero misure runtime.
6. Gli eventi ad alta frequenza devono restare aggregati tramite conteggi e durate; il dettaglio causale è destinato alle sessioni diagnostiche debug/profile.
7. Le chiavi testuali non classificate vengono trasformate in `<redacted-text>`; i tipi oggetto non previsti vengono ridotti al solo tipo runtime.
8. I log hanno finalità diagnostica locale, con retention e rotazione già previste dall'app.
