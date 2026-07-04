import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// No description provided for @appTitle.
  ///
  /// In it, this message translates to:
  /// **'Total Tracker'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settings;

  /// No description provided for @settingsSections.
  ///
  /// In it, this message translates to:
  /// **'Sezioni impostazioni'**
  String get settingsSections;

  /// No description provided for @settingsIntro.
  ///
  /// In it, this message translates to:
  /// **'Ogni scheda apre una pagina dedicata. Le chiavi di navigazione sono codici stabili e non dipendono dal testo visualizzato.'**
  String get settingsIntro;

  /// No description provided for @personalData.
  ///
  /// In it, this message translates to:
  /// **'Dati personali'**
  String get personalData;

  /// No description provided for @personalDataSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Nome, età, sesso, altezza e peso iniziale.'**
  String get personalDataSubtitle;

  /// No description provided for @targetAndActivity.
  ///
  /// In it, this message translates to:
  /// **'Target e attività'**
  String get targetAndActivity;

  /// No description provided for @targetAndActivitySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Target calorico, sorgenti attività e dettaglio dei calcoli.'**
  String get targetAndActivitySubtitle;

  /// No description provided for @mealsAndMacros.
  ///
  /// In it, this message translates to:
  /// **'Pasti e macro'**
  String get mealsAndMacros;

  /// No description provided for @mealsAndMacrosSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Quote per pasto, macronutrienti, fibre e zuccheri.'**
  String get mealsAndMacrosSubtitle;

  /// No description provided for @navigation.
  ///
  /// In it, this message translates to:
  /// **'Navigazione'**
  String get navigation;

  /// No description provided for @navigationSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Dashboard iniziale e comportamento del pulsante Indietro.'**
  String get navigationSubtitle;

  /// No description provided for @notifications.
  ///
  /// In it, this message translates to:
  /// **'Notifiche'**
  String get notifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Promemoria pasti, peso, misurazioni e operazioni in background.'**
  String get notificationsSubtitle;

  /// No description provided for @devicePermissions.
  ///
  /// In it, this message translates to:
  /// **'Permessi dispositivo'**
  String get devicePermissions;

  /// No description provided for @devicePermissionsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Stato reale di notifiche, fotocamera e ottimizzazione batteria.'**
  String get devicePermissionsSubtitle;

  /// No description provided for @onlineFoodSources.
  ///
  /// In it, this message translates to:
  /// **'Fonti alimentari online'**
  String get onlineFoodSources;

  /// No description provided for @onlineFoodSourcesSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Gestisci Open Food Facts e OpenNutrition in un\'unica sezione.'**
  String get onlineFoodSourcesSubtitle;

  /// No description provided for @transfer.
  ///
  /// In it, this message translates to:
  /// **'Import / Export'**
  String get transfer;

  /// No description provided for @transferSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Archivi .totaltracker, cartella export e import selettivo.'**
  String get transferSubtitle;

  /// No description provided for @appAndData.
  ///
  /// In it, this message translates to:
  /// **'App e dati'**
  String get appAndData;

  /// No description provided for @appAndDataSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Tema, lingua, versione, directory e dati locali.'**
  String get appAndDataSubtitle;

  /// No description provided for @openFoodFacts.
  ///
  /// In it, this message translates to:
  /// **'Open Food Facts'**
  String get openFoodFacts;

  /// No description provided for @enableOpenFoodFacts.
  ///
  /// In it, this message translates to:
  /// **'Abilita Open Food Facts'**
  String get enableOpenFoodFacts;

  /// No description provided for @openFoodFactsDescription.
  ///
  /// In it, this message translates to:
  /// **'Controlla ricerca online, scanner barcode e importazioni. Gli alimenti già importati restano disponibili.'**
  String get openFoodFactsDescription;

  /// No description provided for @openNutrition.
  ///
  /// In it, this message translates to:
  /// **'OpenNutrition'**
  String get openNutrition;

  /// No description provided for @enableOpenNutrition.
  ///
  /// In it, this message translates to:
  /// **'Abilita ricerca OpenNutrition'**
  String get enableOpenNutrition;

  /// No description provided for @openNutritionDescription.
  ///
  /// In it, this message translates to:
  /// **'Usa OpenNutrition come fonte complementare tramite indice statico. Gli alimenti già importati restano disponibili.'**
  String get openNutritionDescription;

  /// No description provided for @openNutritionAdvanced.
  ///
  /// In it, this message translates to:
  /// **'Configurazione OpenNutrition'**
  String get openNutritionAdvanced;

  /// No description provided for @openNutritionAdvancedDescription.
  ///
  /// In it, this message translates to:
  /// **'Policy di rete, indice statico, traduzione locale, attribuzioni e diagnostica.'**
  String get openNutritionAdvancedDescription;

  /// No description provided for @openAdvancedSettings.
  ///
  /// In it, this message translates to:
  /// **'Apri impostazioni avanzate'**
  String get openAdvancedSettings;

  /// No description provided for @onlineSourcesIndependent.
  ///
  /// In it, this message translates to:
  /// **'Le due fonti sono indipendenti: puoi abilitarne una, entrambe o nessuna.'**
  String get onlineSourcesIndependent;

  /// No description provided for @interactiveBody.
  ///
  /// In it, this message translates to:
  /// **'Corpo interattivo'**
  String get interactiveBody;

  /// No description provided for @interactiveBodySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Tocca una zona per vedere ultimo valore, variazione e storico.'**
  String get interactiveBodySubtitle;

  /// No description provided for @measurementAvailable.
  ///
  /// In it, this message translates to:
  /// **'Misura disponibile'**
  String get measurementAvailable;

  /// No description provided for @noData.
  ///
  /// In it, this message translates to:
  /// **'Nessun dato'**
  String get noData;

  /// No description provided for @bodyMapSemantics.
  ///
  /// In it, this message translates to:
  /// **'Mappa interattiva delle misure corporee'**
  String get bodyMapSemantics;

  /// No description provided for @neck.
  ///
  /// In it, this message translates to:
  /// **'Collo'**
  String get neck;

  /// No description provided for @shoulders.
  ///
  /// In it, this message translates to:
  /// **'Spalle'**
  String get shoulders;

  /// No description provided for @chest.
  ///
  /// In it, this message translates to:
  /// **'Torace'**
  String get chest;

  /// No description provided for @waist.
  ///
  /// In it, this message translates to:
  /// **'Vita'**
  String get waist;

  /// No description provided for @abdomen.
  ///
  /// In it, this message translates to:
  /// **'Addome'**
  String get abdomen;

  /// No description provided for @hips.
  ///
  /// In it, this message translates to:
  /// **'Fianchi'**
  String get hips;

  /// No description provided for @leftArm.
  ///
  /// In it, this message translates to:
  /// **'Braccio sinistro'**
  String get leftArm;

  /// No description provided for @rightArm.
  ///
  /// In it, this message translates to:
  /// **'Braccio destro'**
  String get rightArm;

  /// No description provided for @leftForearm.
  ///
  /// In it, this message translates to:
  /// **'Avambraccio sinistro'**
  String get leftForearm;

  /// No description provided for @rightForearm.
  ///
  /// In it, this message translates to:
  /// **'Avambraccio destro'**
  String get rightForearm;

  /// No description provided for @leftThigh.
  ///
  /// In it, this message translates to:
  /// **'Coscia sinistra'**
  String get leftThigh;

  /// No description provided for @rightThigh.
  ///
  /// In it, this message translates to:
  /// **'Coscia destra'**
  String get rightThigh;

  /// No description provided for @leftCalf.
  ///
  /// In it, this message translates to:
  /// **'Polpaccio sinistro'**
  String get leftCalf;

  /// No description provided for @rightCalf.
  ///
  /// In it, this message translates to:
  /// **'Polpaccio destro'**
  String get rightCalf;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
