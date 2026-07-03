import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FoodServicePreferenceKeys {
  const FoodServicePreferenceKeys._();

  static const openNutritionSearchEnabled =
      'food.open_nutrition.search_enabled';
  static const openFoodFactsEnabled = 'food.open_food_facts.enabled';

  static const notificationsEnabled = 'notifications.enabled';
  static const mealReminderEnabled = 'notifications.meal_reminder.enabled';
  static const weightReminderEnabled = 'notifications.weight_reminder.enabled';
  static const bodyReminderEnabled = 'notifications.body_reminder.enabled';
  static const backgroundOperationsEnabled =
      'notifications.background_operations.enabled';

  static const notificationTrackingReferenceEpoch =
      'notifications.tracking_reference_epoch';
  static const lastMealReminderDate = 'notifications.meal_reminder.last_date';
  static const lastWeightReminderReference =
      'notifications.weight_reminder.last_reference';
  static const lastBodyReminderReference =
      'notifications.body_reminder.last_reference';
}

class FoodServicePreferences {
  const FoodServicePreferences._();

  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<bool> getBool(
    String key, {
    bool defaultValue = true,
  }) async {
    try {
      return await _preferences.getBool(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  static Future<void> setBool(
    String key,
    bool value,
  ) {
    return _preferences.setBool(key, value);
  }

  static Future<int?> getInt(String key) async {
    try {
      return await _preferences.getInt(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setInt(
    String key,
    int value,
  ) {
    return _preferences.setInt(key, value);
  }

  static Future<String> getString(String key) async {
    try {
      return await _preferences.getString(key) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> setString(
    String key,
    String value,
  ) {
    return _preferences.setString(key, value);
  }

  static Future<bool> isOpenNutritionSearchEnabled() {
    return getBool(
      FoodServicePreferenceKeys.openNutritionSearchEnabled,
    );
  }

  static Future<bool> isOpenFoodFactsEnabled() {
    return getBool(
      FoodServicePreferenceKeys.openFoodFactsEnabled,
    );
  }
}

class FoodServicePreferencesController extends ChangeNotifier {
  bool loading = true;

  bool openNutritionSearchEnabled = true;
  bool openFoodFactsEnabled = true;

  bool notificationsEnabled = false;
  bool mealReminderEnabled = true;
  bool weightReminderEnabled = true;
  bool bodyReminderEnabled = true;
  bool backgroundOperationsEnabled = true;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    openNutritionSearchEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.openNutritionSearchEnabled,
    );
    openFoodFactsEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.openFoodFactsEnabled,
    );
    notificationsEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.notificationsEnabled,
      defaultValue: false,
    );
    mealReminderEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.mealReminderEnabled,
    );
    weightReminderEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.weightReminderEnabled,
    );
    bodyReminderEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.bodyReminderEnabled,
    );
    backgroundOperationsEnabled = await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.backgroundOperationsEnabled,
    );

    loading = false;
    notifyListeners();
  }

  Future<void> _set(
    String key,
    bool value,
    void Function() update,
  ) async {
    update();
    notifyListeners();
    await FoodServicePreferences.setBool(key, value);
  }

  Future<void> setOpenNutritionSearchEnabled(
    bool value,
  ) =>
      _set(
        FoodServicePreferenceKeys.openNutritionSearchEnabled,
        value,
        () => openNutritionSearchEnabled = value,
      );

  Future<void> setOpenFoodFactsEnabled(
    bool value,
  ) =>
      _set(
        FoodServicePreferenceKeys.openFoodFactsEnabled,
        value,
        () => openFoodFactsEnabled = value,
      );

  Future<void> setNotificationsEnabled(
    bool value,
  ) =>
      _set(
        FoodServicePreferenceKeys.notificationsEnabled,
        value,
        () => notificationsEnabled = value,
      );

  Future<void> setMealReminderEnabled(
    bool value,
  ) =>
      _set(
        FoodServicePreferenceKeys.mealReminderEnabled,
        value,
        () => mealReminderEnabled = value,
      );

  Future<void> setWeightReminderEnabled(
    bool value,
  ) =>
      _set(
        FoodServicePreferenceKeys.weightReminderEnabled,
        value,
        () => weightReminderEnabled = value,
      );

  Future<void> setBodyReminderEnabled(
    bool value,
  ) =>
      _set(
        FoodServicePreferenceKeys.bodyReminderEnabled,
        value,
        () => bodyReminderEnabled = value,
      );

  Future<void> setBackgroundOperationsEnabled(
    bool value,
  ) =>
      _set(
        FoodServicePreferenceKeys.backgroundOperationsEnabled,
        value,
        () => backgroundOperationsEnabled = value,
      );
}

final foodServicePreferencesProvider =
    ChangeNotifierProvider<FoodServicePreferencesController>((Ref ref) {
  final FoodServicePreferencesController controller =
      FoodServicePreferencesController();
  controller.load();
  return controller;
});
