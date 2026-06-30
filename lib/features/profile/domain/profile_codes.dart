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
