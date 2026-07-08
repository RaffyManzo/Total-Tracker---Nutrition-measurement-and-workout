# Total Tracker transfer coverage audit

Sessione bugfix: `fix/0.1.0-07-stability-performance-lifecycle`

Baseline verificata:

- `APP_VERSION_BASE=0.1.0+19`
- `TRANSFER_SCHEMA_VERSION=2`
- `OBJECTBOX_MODEL_VERSION=1`
- Versioni importabili: `1..2`
- Archivi futuri: rifiutati da `TransferArchiveCodec.decode`.

## Matrice copertura

| Area | Entita / campo | Export | Import | Strategia migrazione | Test |
| --- | --- | --- | --- | --- | --- |
| Profile | `UserProfileEntity` campi anagrafici, preferenze, target, macro, activity estimator | Incluso | Incluso | DTO map v2, overwrite/keep/import copy | `transfer_current_model_contract_test` |
| Food | `IngredientEntity` nutrienti, origine, immagine, audit active | Incluso se non soft-deleted | Incluso | UUID conflict resolution | `total_tracker_transfer_service_test` |
| Food | `DailyRecordEntity` target theo5, hash input, TDEE, workout kcal, completeness | Incluso | Incluso | `_dayToMapTheo5`, `_applyTheo5DayFields` | `transfer_current_model_contract_test` |
| Food | `MealEntity`, `MealItemEntity`, snapshot nutrizionali | Incluso se non soft-deleted | Incluso | relazioni per UUID/date | transfer service tests |
| Food | `RecipeEntity`, ingredienti, step, snapshot, media sidecar | Incluso se non soft-deleted | Incluso | children ricostruiti dopo parent | transfer service tests |
| Measurements | `ScaleMeasurementEntity` composizione, device, anomaly confirmation, audit | Incluso se non soft-deleted | Incluso | `_scaleToMapTheo5`, `_applyTheo5ScaleFields` | `measurement_repository_delete_test`, `transfer_current_model_contract_test` |
| Measurements | `TapeMeasurementEntity`, `TapeMeasurementEntryEntity` valori e posizioni | Incluso se non soft-deleted | Incluso | children sostituiti in import | `measurement_repository_delete_test` |
| Workout | muscoli, esercizi, routine, piani, sessioni, set | Incluso se non soft-deleted | Incluso | import parent-first, relazioni ricostruite | workout/transfer tests esistenti |
| Runtime | invalidation queue, timer, stream, log, lock | Escluso | Escluso | transitorio/ricostruibile | n/a |
| Privacy | token, segreti, percorsi privati non necessari, log | Escluso | Escluso | non portabile | `transfer_archive_security_test` |

## Note su tombstone

Il formato corrente esporta lo stato portabile attivo e non include record soft-deleted. La patch rende coerente il comportamento metro: la cancellazione lascia tombstone in ObjectBox e le query/export attivi li escludono. Un eventuale schema futuro potra includere tombstone espliciti per sincronizzazione multi-device; richiederebbe incremento schema e migrazione.

## Esiti accettazione

- `TRANSFER_SCHEMA_VERSION=2`
- `TRANSFER_CURRENT_MODEL_COVERAGE=COMPLETE_ACTIVE_PORTABLE_STATE`
- `TRANSFER_PREVIOUS_VERSION_IMPORT=COVERED_BY_CODEC_VERSION_1_COMPAT`
- `TRANSFER_EMPTY_STORE_ROUNDTRIP=COVERED_BY_TRANSFER_TESTS`
- `TRANSFER_CORRUPTION_ROLLBACK=COVERED_BY_CODEC_SECURITY_TESTS`
