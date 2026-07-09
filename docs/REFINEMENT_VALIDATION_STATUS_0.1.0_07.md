# Stato validazione refinement 0.1.0-07

Questo file descrive lo stato del pacchetto prima dell’esecuzione del launcher.

| Requisito | Stato pacchetto |
|---|---|
| Base remota esatta | verificata dal launcher |
| Patch deterministica | inclusa |
| Schema 2 round-trip | test reale incluso |
| Schema 1 fixture | inclusa |
| Archivio corrotto senza mutazioni | test incluso |
| Rollback atomico transazione write | test forzato incluso |
| Picker selezione/quantità/compressione/10 cicli/istanza singola | widget test incluso |
| Pop creazione dispositivo, riapertura e completamento | widget test incluso |
| Lifecycle distinto/idempotente | codice e test inclusi |
| Metriche pub/sub reali | codice e test inclusi |
| Loading >200 ms/minimo | codice e test inclusi |
| Privacy logging deny-by-default per stringhe | codice, inventario e test inclusi |
| Analyze/test/build | non eseguiti in questo ambiente; obbligatori nel probe |
| Log telefono 1 | PENDING_USER_PHONE_TEST |
| Log telefono 2 | PENDING_USER_PHONE_TEST |
| Beneficio runtime pub/sub | NOT_VERIFIED_PENDING_DEVICE_LOGS |

`REFINEMENT_RESULT=PASS` può essere emesso soltanto dal launcher dopo il probe e la validazione reale. I requisiti device restano pendenti anche in caso di successo locale.
