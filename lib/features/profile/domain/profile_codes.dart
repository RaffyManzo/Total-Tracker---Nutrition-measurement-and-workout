class BiologicalSexCodes {
  const BiologicalSexCodes._();

  static const String unspecified = 'unspecified';
  static const String female = 'female';
  static const String male = 'male';
  static const String other = 'other';

  static const Set<String> values = <String>{
    unspecified,
    female,
    male,
    other,
  };
}

class TargetModeCodes {
  const TargetModeCodes._();

  static const String fixedUser = 'fixed_user';
  static const String appCalculatedFixed = 'app_calculated_fixed';
  static const String adaptiveWeekly = 'adaptive_weekly';

  static const Set<String> values = <String>{
    fixedUser,
    appCalculatedFixed,
    adaptiveWeekly,
  };
}

class MealTargetModeCodes {
  const MealTargetModeCodes._();

  static const String none = 'none';
  static const String shared = 'shared';
  static const String custom = 'custom';

  static const Set<String> values = <String>{
    none,
    shared,
    custom,
  };
}

class ActivityFallbackModeCodes {
  const ActivityFallbackModeCodes._();

  static const String recordedWithProfileFallback =
      'recorded_with_profile_fallback';
  static const String recordedOnly = 'recorded_only';
  static const String profileEstimate = 'profile_estimate';

  static const Set<String> values = <String>{
    recordedWithProfileFallback,
    recordedOnly,
    profileEstimate,
  };
}

class MacroModeCodes {
  const MacroModeCodes._();

  static const String defaultByWeight = 'default_by_weight';
  static const String custom = 'custom';

  static const Set<String> values = <String>{
    defaultByWeight,
    custom,
  };
}

class WorkoutActivityTypeCodes {
  const WorkoutActivityTypeCodes._();

  static const String weights = 'weights';
  static const String mixed = 'mixed';
  static const String cardio = 'cardio';

  static const Set<String> values = <String>{
    weights,
    mixed,
    cardio,
  };
}

class ThemePreferenceCodes {
  const ThemePreferenceCodes._();

  static const String system = 'system';
  static const String light = 'light';
  static const String dark = 'dark';

  static const Set<String> values = <String>{
    system,
    light,
    dark,
  };
}
