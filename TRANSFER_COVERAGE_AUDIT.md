# Total Tracker transfer coverage audit — refinement 0.1.0-07

Base: `75a0a4c277774471843815acea5fddebd6fa7dcd`
Formato corrente: schema 2
Compatibilità lettura: schema 1 e 2

## Inventario servizio/DTO/manifest

Il servizio corrente esporta e importa in un'unica architettura le sezioni `profile`, `ingredients`, `recipes`, `days`, `meals`, `scaleMeasurements`, `tapeMeasurements`, `muscles`, `exercises`, `routines`, `workoutPlans` e `workoutSessions`. Le relazioni figlio sono incluse nei DTO parent: ingredienti/passaggi ricetta, item pasto, misure metro, link muscolari, esercizi/serie routine, giorni/esercizi scheda ed esercizi/serie sessione.

| Area | Contratto portabile ispezionato | Evidenza eseguibile |
|---|---|---|
| Profile | DTO campo-per-campo e strategie conflitto | suite completa del repository |
| Ingredienti | nutrizione, origine, immagine/media, audit | round-trip reale tra due store, confronto canonico |
| Giorni/pasti/item | snapshot, target e relazioni | suite completa + export schema 2 nel probe |
| Ricette/media | parent, ingredienti, passaggi, riferimenti media | suite completa + inventario mapper |
| Bilancia/metro | composizione e children | suite completa + inventario mapper |
| Workout | muscoli, esercizi, routine, piani, sessioni e set | regressione fondazione + suite completa |
| Soft delete | record tombstone esclusi dall'export | ingrediente soft-deleted escluso dal round-trip |
| Conflitti | overwrite, keep existing, import copy | test servizio esistente + doppia importazione |
| Schema 1 | checksum FNV-1a e migrazione | fixture binaria reale importata |
| Corruzione | ZIP/checksum/JSON rifiutati prima della scrittura | archivio troncato, store invariato |
| Atomicità | `applyImport` usa una singola transazione ObjectBox write | test di rollback forzato sulla stessa primitiva transazionale |
| Runtime/segreti | esclusi dal formato | audit sicurezza esistente |

## Limite esplicito

Il nuovo round-trip seed-a direttamente un ingrediente completo, un riferimento media e un tombstone in uno Store sorgente, esporta un archivio reale e lo importa in uno Store distinto. Non pretende da solo di dimostrare ogni mapper. La prova cumulativa richiesta dal launcher comprende questo test mirato, i test transfer/security già presenti e infine l'intera suite `flutter test`.

Il rollback è dimostrato separatamente su due livelli: un archivio corrotto viene respinto prima della transazione e una failure forzata dentro `Store.runInTransaction(TxMode.write)` annulla tutte le scritture parziali. Non viene introdotto un secondo motore transfer né viene incrementato lo schema.
