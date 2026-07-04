// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Total Tracker';

  @override
  String get settings => 'Impostazioni';

  @override
  String get settingsSections => 'Sezioni impostazioni';

  @override
  String get settingsIntro =>
      'Ogni scheda apre una pagina dedicata. Le chiavi di navigazione sono codici stabili e non dipendono dal testo visualizzato.';

  @override
  String get personalData => 'Dati personali';

  @override
  String get personalDataSubtitle =>
      'Nome, età, sesso, altezza e peso iniziale.';

  @override
  String get targetAndActivity => 'Target e attività';

  @override
  String get targetAndActivitySubtitle =>
      'Target calorico, sorgenti attività e dettaglio dei calcoli.';

  @override
  String get mealsAndMacros => 'Pasti e macro';

  @override
  String get mealsAndMacrosSubtitle =>
      'Quote per pasto, macronutrienti, fibre e zuccheri.';

  @override
  String get navigation => 'Navigazione';

  @override
  String get navigationSubtitle =>
      'Dashboard iniziale e comportamento del pulsante Indietro.';

  @override
  String get notifications => 'Notifiche';

  @override
  String get notificationsSubtitle =>
      'Promemoria pasti, peso, misurazioni e operazioni in background.';

  @override
  String get devicePermissions => 'Permessi dispositivo';

  @override
  String get devicePermissionsSubtitle =>
      'Stato reale di notifiche, fotocamera e ottimizzazione batteria.';

  @override
  String get onlineFoodSources => 'Fonti alimentari online';

  @override
  String get onlineFoodSourcesSubtitle =>
      'Gestisci Open Food Facts e OpenNutrition in un\'unica sezione.';

  @override
  String get transfer => 'Import / Export';

  @override
  String get transferSubtitle =>
      'Archivi .totaltracker, cartella export e import selettivo.';

  @override
  String get appAndData => 'App e dati';

  @override
  String get appAndDataSubtitle =>
      'Tema, lingua, versione, directory e dati locali.';

  @override
  String get openFoodFacts => 'Open Food Facts';

  @override
  String get enableOpenFoodFacts => 'Abilita Open Food Facts';

  @override
  String get openFoodFactsDescription =>
      'Controlla ricerca online, scanner barcode e importazioni. Gli alimenti già importati restano disponibili.';

  @override
  String get openNutrition => 'OpenNutrition';

  @override
  String get enableOpenNutrition => 'Abilita ricerca OpenNutrition';

  @override
  String get openNutritionDescription =>
      'Usa OpenNutrition come fonte complementare tramite indice statico. Gli alimenti già importati restano disponibili.';

  @override
  String get openNutritionAdvanced => 'Configurazione OpenNutrition';

  @override
  String get openNutritionAdvancedDescription =>
      'Policy di rete, indice statico, traduzione locale, attribuzioni e diagnostica.';

  @override
  String get openAdvancedSettings => 'Apri impostazioni avanzate';

  @override
  String get onlineSourcesIndependent =>
      'Le due fonti sono indipendenti: puoi abilitarne una, entrambe o nessuna.';

  @override
  String get interactiveBody => 'Corpo interattivo';

  @override
  String get interactiveBodySubtitle =>
      'Tocca una zona per vedere ultimo valore, variazione e storico.';

  @override
  String get measurementAvailable => 'Misura disponibile';

  @override
  String get noData => 'Nessun dato';

  @override
  String get bodyMapSemantics => 'Mappa interattiva delle misure corporee';

  @override
  String get neck => 'Collo';

  @override
  String get shoulders => 'Spalle';

  @override
  String get chest => 'Torace';

  @override
  String get waist => 'Vita';

  @override
  String get abdomen => 'Addome';

  @override
  String get hips => 'Fianchi';

  @override
  String get leftArm => 'Braccio sinistro';

  @override
  String get rightArm => 'Braccio destro';

  @override
  String get leftForearm => 'Avambraccio sinistro';

  @override
  String get rightForearm => 'Avambraccio destro';

  @override
  String get leftThigh => 'Coscia sinistra';

  @override
  String get rightThigh => 'Coscia destra';

  @override
  String get leftCalf => 'Polpaccio sinistro';

  @override
  String get rightCalf => 'Polpaccio destro';
}
