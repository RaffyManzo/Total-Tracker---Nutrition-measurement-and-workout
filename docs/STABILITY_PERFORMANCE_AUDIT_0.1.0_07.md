# Stability and performance audit 0.1.0-07

Branch: `fix/0.1.0-07-stability-performance-lifecycle`
Base: `ae7274832589f02f401bc89a91e02126ecf4bee4`

## Baseline dai log allegati

| Area | Evidenza | Costo osservato | Gravita |
| --- | --- | --- | --- |
| Meal ingredient panel | `No Scaffold widget found`, controller disposed, wrong build scope, duplicate GlobalKey | runtime crash | P0 |
| Dashboard target | `dailyTargetResultMs`, observed TDEE dominante | 455-758 ms | P1 |
| Weekly hub | `dailyTargetsMs`, `ensureDaysMs` | 922-1501 ms | P1 |
| Calendar month | outlier aggregazione mese | fino a 839 ms | P2 |
| Add food freeze | tap conferma -> snackbar, UI ancora bloccata | 1-2 s | P1 |
| Android lifecycle | `backgroundMs=34890`, resume non correlato a code/timer/subscription | n/d | P1 |

## Correzioni applicate

| Problema | File/metodo | Correzione | Rischio regressione | Test/validazione |
| --- | --- | --- | --- | --- |
| Picker ingredienti dipendente da `showBottomSheet(context)` senza Scaffold antenato | `meal_ingredient_batch_picker_sheet.dart`, `FoodMealDetailScreen` | Picker montato nel tree dello `Scaffold.body`, controller locale unico, tap ripetuto espande istanza esistente | medio: layout sheet su viewport piccoli | contract test picker, analyze |
| Lifecycle overlay/controller | `MealIngredientBatchPickerController`, `MealIngredientBatchPickerSheet.dispose` | attach/detach esplicito, nessun `OverlayEntry`, nessun controller per riga ingrediente | basso | source contract + widget smoke futuri |
| Cancellazione metro mancante | `MeasurementRepository.softDeleteTape`, `_showTapeDialog` | soft delete misura + entry, azione con conferma, esclusione query attive | medio: import vecchi con entry duplicate | `measurement_repository_delete_test` |
| Controller fogli misurazioni non disposti | `_showScaleDialog`, `_showTapeDialog` | dispose dopo chiusura foglio e lettura valori | basso | analyze |
| Creazione dispositivo dopo pop | `ScaleDeviceConfigurationScreen` | guardie `mounted` dopo ogni await, dispose dialog in finally | basso | analyze + test manuale |
| Recipe bottom `+ Alimento` indesiderato | `OpenNutritionImportOverlay.build` | overlay disattivato per target `recipe` | basso | contract UI |
| Pub/sub non causale | `FoodDataRefreshBus`, `TargetInputChangeBus`, `TargetRecalculationCoordinator` | `eventId`, `operationId`, `queueWaitMs`, `coalescedEventCount`, hash UUID, summary update | basso/medio: log volume | `pubsub_observability_contract_test` |
| Lifecycle resume povero | `FoodHubScreen.didChangeAppLifecycleState` | `lifecycle.resume.started/completed` con snapshot queue/subscriptions/timers/overlays | basso | diagnostics contract |
| Loading immediato | `DelayedLoadingIndicator`, food/measurements/insights | soglia 200 ms locale | basso | analyze |

## Misure prima/dopo

Prima: valori reali riportati nell'handoff, non ripetibili in CI senza device/profile.

Dopo questa patch:

- il percorso P0 del picker non usa piu `showBottomSheet` e quindi rimuove la causa diretta dell'assertion `No Scaffold widget found`;
- il ricalcolo target non e stato dichiarato piu veloce senza device profile; ora emette metriche confrontabili per tap -> publish -> queue -> recalculation -> UI refresh;
- i test locali verificano le regressioni strutturali e repository.

La validazione device/profile rimane necessaria per p50/p95 su almeno 10 aggiunte alimento e 10 cicli background/resume.

## Pub/sub conclusion

Prima: non valutabile, mancavano correlazione e subscriber.

Dopo: valutabile dai log. La patch non afferma beneficio netto; rende misurabili duplicazioni, coalescenza, skip per hash e refresh UI.

## Validazione locale

- `dart format --set-exit-if-changed` sui 26 file Dart modificati: PASS.
- `dart format --set-exit-if-changed lib test`: ha trovato 4 file gia fuori formato fuori scope del bugfix; i file sono stati ripristinati e non inclusi nel commit.
- `flutter analyze --no-pub`: PASS.
- `flutter test --no-pub`: PASS, 199 test.
- `flutter build apk --debug --no-pub`: PASS, con warning Flutter sulla futura migrazione Kotlin Gradle Plugin.
- `git diff --check`: PASS.

Device/profile mode e i 10 cicli reali background/resume non sono stati eseguiti in questa sessione per assenza di un device/profile collegato. I marker diagnostici aggiunti servono a confrontare p50/p95 appena il branch viene lanciato in profile mode.

## Debiti residui

- Portare `observedTdeeMs` sotto profiling reale con ottimizzazione dedicata.
- Estendere il loading ritardato a import/export e ricerca esterna con skeleton locali.
- Se serve sincronizzazione tombstone tra archivi, introdurre schema transfer v3 con migrazione esplicita.
