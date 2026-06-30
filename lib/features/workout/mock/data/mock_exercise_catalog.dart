import '../domain/mock_exercise.dart';

abstract final class MockExerciseCatalog {
  static final List<MockExercise> items = <MockExercise>[
    MockExercise(
      id: 'bench-press',
      name: 'Panca piana bilanciere',
      mode: 'gym',
      media: 'assets/exercises/bench_press.jpg',
      defaultRestSeconds: 120,
      primaryMuscles: <String>['Petto'],
      secondaryMuscles: <String>['Tricipiti', 'Deltoidi anteriori'],
      notes: 'Mantieni le scapole addotte e i piedi stabili.',
      createdAt: DateTime(2026, 6, 28, 9),
      updatedAt: DateTime(2026, 6, 28, 9),
    ),
    MockExercise(
      id: 'treadmill-incline',
      name: 'Treadmill inclinato',
      mode: 'treadmill',
      media: '',
      defaultRestSeconds: 0,
      primaryMuscles: <String>['Quadricipiti', 'Glutei'],
      secondaryMuscles: <String>['Polpacci'],
      notes: 'Registra durata, velocitÃ  media e pendenza media.',
      createdAt: DateTime(2026, 6, 27, 11),
      updatedAt: DateTime(2026, 6, 27, 11),
    ),
    MockExercise(
      id: 'football',
      name: 'Calcio',
      mode: 'activity',
      media: '',
      defaultRestSeconds: 0,
      primaryMuscles: <String>['Gambe'],
      secondaryMuscles: <String>['Core'],
      notes: 'AttivitÃ  libera tracciata per durata e battito medio.',
      createdAt: DateTime(2026, 6, 26, 19),
      updatedAt: DateTime(2026, 6, 26, 19),
    ),
  ];

  static MockExercise? byId(String id) {
    for (final MockExercise exercise in items) {
      if (exercise.id == id) {
        return exercise;
      }
    }
    return null;
  }
}
