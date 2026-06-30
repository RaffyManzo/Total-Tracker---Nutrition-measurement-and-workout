class MockExercise {
  const MockExercise({
    required this.id,
    required this.name,
    required this.mode,
    required this.media,
    required this.defaultRestSeconds,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String mode;
  final String media;
  final int defaultRestSeconds;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
