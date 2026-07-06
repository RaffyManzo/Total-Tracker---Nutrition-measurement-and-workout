import 'package:shared_preferences/shared_preferences.dart';

import '../../features/nutrition/domain/target_model_constants.dart';

class StepsExclusionPolicy {
  const StepsExclusionPolicy._();

  static const String preferenceKey =
      'target_steps_exclusion_banner_dismissed_for_version';
  static const String currentVersion =
      TargetModelConstants.stepsExclusionPolicyVersion;

  static bool shouldShow(String? dismissedVersion) {
    return dismissedVersion != currentVersion;
  }
}

class TargetModelPreferences {
  TargetModelPreferences({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  Future<bool> isStepsExclusionBannerVisible() async {
    final String? dismissed =
        await _preferences.getString(StepsExclusionPolicy.preferenceKey);
    return StepsExclusionPolicy.shouldShow(dismissed);
  }

  Future<void> dismissStepsExclusionBanner() {
    return _preferences.setString(
      StepsExclusionPolicy.preferenceKey,
      StepsExclusionPolicy.currentVersion,
    );
  }

  Future<void> resetInformationalWarnings() {
    return _preferences.remove(StepsExclusionPolicy.preferenceKey);
  }
}
