// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Total Tracker';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSections => 'Settings sections';

  @override
  String get settingsIntro =>
      'Each card opens a dedicated page. Navigation keys use stable codes and do not depend on the displayed text.';

  @override
  String get personalData => 'Personal details';

  @override
  String get personalDataSubtitle =>
      'Name, age, sex, height and initial weight.';

  @override
  String get targetAndActivity => 'Targets and activity';

  @override
  String get targetAndActivitySubtitle =>
      'Calorie target, activity sources and calculation details.';

  @override
  String get mealsAndMacros => 'Meals and macros';

  @override
  String get mealsAndMacrosSubtitle =>
      'Meal shares, macronutrients, fibre and sugars.';

  @override
  String get navigation => 'Navigation';

  @override
  String get navigationSubtitle =>
      'Initial dashboard and Back button behaviour.';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'Meal, weight and measurement reminders, plus background operations.';

  @override
  String get devicePermissions => 'Device permissions';

  @override
  String get devicePermissionsSubtitle =>
      'Current status of notifications, camera and battery optimisation.';

  @override
  String get onlineFoodSources => 'Online food sources';

  @override
  String get onlineFoodSourcesSubtitle =>
      'Manage Open Food Facts and OpenNutrition in one section.';

  @override
  String get transfer => 'Import / Export';

  @override
  String get transferSubtitle =>
      '.totaltracker archives, export folder and selective import.';

  @override
  String get appAndData => 'App and data';

  @override
  String get appAndDataSubtitle =>
      'Theme, language, version, directories and local data.';

  @override
  String get openFoodFacts => 'Open Food Facts';

  @override
  String get enableOpenFoodFacts => 'Enable Open Food Facts';

  @override
  String get openFoodFactsDescription =>
      'Controls online search, barcode scanning and imports. Previously imported foods remain available.';

  @override
  String get openNutrition => 'OpenNutrition';

  @override
  String get enableOpenNutrition => 'Enable OpenNutrition search';

  @override
  String get openNutritionDescription =>
      'Uses OpenNutrition as a complementary source through the static index. Previously imported foods remain available.';

  @override
  String get openNutritionAdvanced => 'OpenNutrition configuration';

  @override
  String get openNutritionAdvancedDescription =>
      'Network policy, static index, on-device translation, attribution and diagnostics.';

  @override
  String get openAdvancedSettings => 'Open advanced settings';

  @override
  String get onlineSourcesIndependent =>
      'The two sources are independent: you can enable either one, both, or neither.';

  @override
  String get interactiveBody => 'Interactive body map';

  @override
  String get interactiveBodySubtitle =>
      'Tap a region to view its latest value, change and history.';

  @override
  String get measurementAvailable => 'Measurement available';

  @override
  String get noData => 'No data';

  @override
  String get bodyMapSemantics => 'Interactive body measurement map';

  @override
  String get neck => 'Neck';

  @override
  String get shoulders => 'Shoulders';

  @override
  String get chest => 'Chest';

  @override
  String get waist => 'Waist';

  @override
  String get abdomen => 'Abdomen';

  @override
  String get hips => 'Hips';

  @override
  String get leftArm => 'Left arm';

  @override
  String get rightArm => 'Right arm';

  @override
  String get leftForearm => 'Left forearm';

  @override
  String get rightForearm => 'Right forearm';

  @override
  String get leftThigh => 'Left thigh';

  @override
  String get rightThigh => 'Right thigh';

  @override
  String get leftCalf => 'Left calf';

  @override
  String get rightCalf => 'Right calf';

  @override
  String get bodyTorsoGroup => 'Torso';

  @override
  String get bodyArmsGroup => 'Arms';

  @override
  String get bodyLegsGroup => 'Legs';

  @override
  String get bodyMeasurementsList => 'Recorded measurements';

  @override
  String get bodyMeasurementsListHint =>
      'Open a group and tap a measurement to view its history.';
}
