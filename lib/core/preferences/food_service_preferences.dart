import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OpenNutritionNetworkPolicy {
  wifiOnly(
    code: 'wifi_only',
    label: 'Solo Wi-Fi',
    description: 'OpenNutrition usa Wi-Fi o Ethernet, mai i dati mobili.',
  ),
  mobileOnly(
    code: 'mobile_only',
    label: 'Solo dati mobili',
    description: 'OpenNutrition usa la rete cellulare, non il Wi-Fi.',
  ),
  wifiAndMobile(
    code: 'wifi_and_mobile',
    label: 'Wi-Fi e dati mobili',
    description: 'OpenNutrition può usare entrambe le connessioni.',
  );

  const OpenNutritionNetworkPolicy({
    required this.code,
    required this.label,
    required this.description,
  });

  final String code;
  final String label;
  final String description;

  static OpenNutritionNetworkPolicy fromCode(String code) {
    return OpenNutritionNetworkPolicy.values.firstWhere(
      (OpenNutritionNetworkPolicy value) => value.code == code,
      orElse: () => OpenNutritionNetworkPolicy.wifiAndMobile,
    );
  }
}

class FoodServicePreferenceKeys {
  const FoodServicePreferenceKeys._();

  static const String openNutritionSearchEnabled =
      'food.open_nutrition.search_enabled';
  static const String openNutritionNetworkPolicy =
      'food.open_nutrition.network_policy';
  static const String openNutritionRemoteEnabled =
      'food.open_nutrition.remote_enabled';
  static const String openNutritionGatewayUrl =
      'food.open_nutrition.gateway_url';
  static const String openNutritionGatewayPublicKey =
      'food.open_nutrition.gateway_public_key';
  static const String openNutritionGatewayKeyId =
      'food.open_nutrition.gateway_key_id';
  static const String gatewayInstallationId =
      'food.open_nutrition.gateway_installation_id';

  static const String openFoodFactsEnabled = 'food.open_food_facts.enabled';

  static const String notificationsEnabled = 'notifications.enabled';
  static const String mealReminderEnabled =
      'notifications.meal_reminder.enabled';
  static const String weightReminderEnabled =
      'notifications.weight_reminder.enabled';
  static const String bodyReminderEnabled =
      'notifications.body_reminder.enabled';
  static const String backgroundOperationsEnabled =
      'notifications.background_operations.enabled';

  static const String notificationTrackingReferenceEpoch =
      'notifications.tracking_reference_epoch';
  static const String lastMealReminderDate =
      'notifications.meal_reminder.last_date';
  static const String lastWeightReminderReference =
      'notifications.weight_reminder.last_reference';
  static const String lastBodyReminderReference =
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

  static Future<void> setBool(String key, bool value) {
    return _preferences.setBool(key, value);
  }

  static Future<int?> getInt(String key) async {
    try {
      return await _preferences.getInt(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setInt(String key, int value) {
    return _preferences.setInt(key, value);
  }

  static Future<String> getString(String key) async {
    try {
      return await _preferences.getString(key) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  static Future<void> remove(String key) {
    return _preferences.remove(key);
  }

  static Future<bool> isOpenNutritionSearchEnabled() {
    return getBool(FoodServicePreferenceKeys.openNutritionSearchEnabled);
  }

  static Future<OpenNutritionNetworkPolicy>
      getOpenNutritionNetworkPolicy() async {
    final String code = await getString(
      FoodServicePreferenceKeys.openNutritionNetworkPolicy,
    );
    return OpenNutritionNetworkPolicy.fromCode(code);
  }

  static Future<bool> isOpenNutritionRemoteEnabled() {
    return getBool(
      FoodServicePreferenceKeys.openNutritionRemoteEnabled,
      defaultValue: true,
    );
  }

  static Future<bool> isOpenFoodFactsEnabled() {
    return getBool(FoodServicePreferenceKeys.openFoodFactsEnabled);
  }
}

class FoodServicePreferencesController extends ChangeNotifier {
  bool loading = true;

  bool openNutritionSearchEnabled = true;
  OpenNutritionNetworkPolicy openNutritionNetworkPolicy =
      OpenNutritionNetworkPolicy.wifiAndMobile;
  bool openNutritionRemoteEnabled = true;
  bool openFoodFactsEnabled = true;

  bool notificationsEnabled = false;
  bool mealReminderEnabled = true;
  bool weightReminderEnabled = true;
  bool bodyReminderEnabled = true;
  bool backgroundOperationsEnabled = true;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      openNutritionSearchEnabled = await FoodServicePreferences.getBool(
        FoodServicePreferenceKeys.openNutritionSearchEnabled,
      );
      openNutritionNetworkPolicy =
          await FoodServicePreferences.getOpenNutritionNetworkPolicy();
      openNutritionRemoteEnabled = await FoodServicePreferences.getBool(
        FoodServicePreferenceKeys.openNutritionRemoteEnabled,
        defaultValue: true,
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
    } finally {
      loading = false;
      notifyListeners();
    }
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

  Future<void> setOpenNutritionSearchEnabled(bool value) => _set(
        FoodServicePreferenceKeys.openNutritionSearchEnabled,
        value,
        () => openNutritionSearchEnabled = value,
      );

  Future<void> setOpenNutritionNetworkPolicy(
    OpenNutritionNetworkPolicy value,
  ) async {
    openNutritionNetworkPolicy = value;
    notifyListeners();
    await FoodServicePreferences.setString(
      FoodServicePreferenceKeys.openNutritionNetworkPolicy,
      value.code,
    );
  }

  Future<void> setOpenNutritionRemoteEnabled(bool value) => _set(
        FoodServicePreferenceKeys.openNutritionRemoteEnabled,
        value,
        () => openNutritionRemoteEnabled = value,
      );

  Future<void> setOpenFoodFactsEnabled(bool value) => _set(
        FoodServicePreferenceKeys.openFoodFactsEnabled,
        value,
        () => openFoodFactsEnabled = value,
      );

  Future<void> setNotificationsEnabled(bool value) => _set(
        FoodServicePreferenceKeys.notificationsEnabled,
        value,
        () => notificationsEnabled = value,
      );

  Future<void> setMealReminderEnabled(bool value) => _set(
        FoodServicePreferenceKeys.mealReminderEnabled,
        value,
        () => mealReminderEnabled = value,
      );

  Future<void> setWeightReminderEnabled(bool value) => _set(
        FoodServicePreferenceKeys.weightReminderEnabled,
        value,
        () => weightReminderEnabled = value,
      );

  Future<void> setBodyReminderEnabled(bool value) => _set(
        FoodServicePreferenceKeys.bodyReminderEnabled,
        value,
        () => bodyReminderEnabled = value,
      );

  Future<void> setBackgroundOperationsEnabled(bool value) => _set(
        FoodServicePreferenceKeys.backgroundOperationsEnabled,
        value,
        () => backgroundOperationsEnabled = value,
      );

  Future<void> setAllNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    mealReminderEnabled = value;
    weightReminderEnabled = value;
    bodyReminderEnabled = value;
    backgroundOperationsEnabled = value;
    notifyListeners();

    await Future.wait(<Future<void>>[
      FoodServicePreferences.setBool(
        FoodServicePreferenceKeys.notificationsEnabled,
        value,
      ),
      FoodServicePreferences.setBool(
        FoodServicePreferenceKeys.mealReminderEnabled,
        value,
      ),
      FoodServicePreferences.setBool(
        FoodServicePreferenceKeys.weightReminderEnabled,
        value,
      ),
      FoodServicePreferences.setBool(
        FoodServicePreferenceKeys.bodyReminderEnabled,
        value,
      ),
      FoodServicePreferences.setBool(
        FoodServicePreferenceKeys.backgroundOperationsEnabled,
        value,
      ),
    ]);
  }
}

final foodServicePreferencesProvider =
    ChangeNotifierProvider<FoodServicePreferencesController>((Ref ref) {
  final FoodServicePreferencesController controller =
      FoodServicePreferencesController();
  controller.load();
  return controller;
});
