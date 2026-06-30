class ExerciseModeCodes {
  const ExerciseModeCodes._();

  static const String gym = 'gym';
  static const String activity = 'activity';
  static const String treadmill = 'treadmill';

  static const Set<String> values = <String>{
    gym,
    activity,
    treadmill,
  };
}

class MuscleRoleCodes {
  const MuscleRoleCodes._();

  static const String primary = 'primary';
  static const String secondary = 'secondary';

  static const Set<String> values = <String>{
    primary,
    secondary,
  };
}

class MuscleBodyRegionCodes {
  const MuscleBodyRegionCodes._();

  static const String upperBody = 'upper_body';
  static const String core = 'core';
  static const String lowerBody = 'lower_body';
  static const String fullBody = 'full_body';
}

class MuscleGroupCodes {
  const MuscleGroupCodes._();

  static const String chest = 'chest';
  static const String shoulders = 'shoulders';
  static const String back = 'back';
  static const String biceps = 'biceps';
  static const String triceps = 'triceps';
  static const String forearms = 'forearms';
  static const String core = 'core';
  static const String glutes = 'glutes';
  static const String hips = 'hips';
  static const String quadriceps = 'quadriceps';
  static const String hamstrings = 'hamstrings';
  static const String calves = 'calves';
  static const String lowerLeg = 'lower_leg';
  static const String general = 'general';
}
