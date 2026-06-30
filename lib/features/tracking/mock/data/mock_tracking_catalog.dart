import '../domain/mock_tracking_models.dart';

abstract final class MockTrackingCatalog {
  static const List<MockDayRecord> days = <MockDayRecord>[
    MockDayRecord(
      id: '2026-06-29',
      dateLabel: 'Lunedì 29 giugno',
      weekLabel: 'Settimana 26',
      targetKcal: 2050,
      caloriesIn: 1880,
      activeKcal: 410,
      steps: 9320,
      weightKg: 63.35,
      waterLiters: 2.2,
      sleepHours: 7.4,
      notes: 'Giornata regolare, allenamento completato.',
    ),
    MockDayRecord(
      id: '2026-06-28',
      dateLabel: 'Domenica 28 giugno',
      weekLabel: 'Settimana 26',
      targetKcal: 2000,
      caloriesIn: 2140,
      activeKcal: 260,
      steps: 6810,
      weightKg: 63.50,
      waterLiters: 1.8,
      sleepHours: 6.9,
      notes: 'Pasto libero tracciato.',
    ),
  ];

  static const List<MockMeal> meals = <MockMeal>[
    MockMeal(
      id: 'meal-breakfast',
      title: 'Colazione',
      mealType: 'Colazione',
      dateLabel: '29 giugno 2026',
      mode: 'Standard',
      kcal: 510,
      protein: 31,
      carbs: 59,
      fat: 16,
      items: <String>[
        'Yogurt greco · 150 g',
        'Fiocchi di avena · 60 g',
        'Banana · 110 g',
      ],
      notes: 'Colazione pre-allenamento.',
    ),
    MockMeal(
      id: 'meal-lunch',
      title: 'Pranzo',
      mealType: 'Pranzo',
      dateLabel: '29 giugno 2026',
      mode: 'Standard',
      kcal: 720,
      protein: 54,
      carbs: 79,
      fat: 18,
      items: <String>[
        'Petto di pollo · 180 g',
        'Riso basmati · 100 g',
        'Olio EVO · 10 g',
      ],
      notes: '',
    ),
    MockMeal(
      id: 'meal-free',
      title: 'Cena libera',
      mealType: 'Cena',
      dateLabel: '28 giugno 2026',
      mode: 'Pasto libero stimato',
      kcal: 980,
      protein: 38,
      carbs: 112,
      fat: 41,
      items: <String>['Pizza margherita · stima manuale'],
      notes: 'Valore stimato con affidabilità normale.',
    ),
  ];

  static const List<MockRecipe> recipes = <MockRecipe>[
    MockRecipe(
      id: 'recipe-rice-chicken',
      title: 'Riso e pollo cremoso',
      subtitle: 'Piatto unico ad alto contenuto proteico',
      servings: 2,
      totalMinutes: 35,
      difficulty: 'Facile',
      kcalPerServing: 610,
      proteinPer100: 12.4,
      carbsPer100: 18.8,
      fatPer100: 5.6,
      ingredients: <String>[
        'Riso basmati · 180 g',
        'Petto di pollo · 320 g',
        'Yogurt greco · 120 g',
        'Spezie e sale',
      ],
      steps: <String>[
        'Cuoci il riso.',
        'Rosola il pollo con le spezie.',
        'Unisci yogurt e riso fuori dal fuoco.',
      ],
      tags: <String>['Proteica', 'Meal prep', 'Pranzo'],
    ),
    MockRecipe(
      id: 'recipe-oats',
      title: 'Porridge cacao e banana',
      subtitle: 'Colazione rapida',
      servings: 1,
      totalMinutes: 10,
      difficulty: 'Facile',
      kcalPerServing: 470,
      proteinPer100: 8.7,
      carbsPer100: 20.5,
      fatPer100: 4.2,
      ingredients: <String>[
        'Fiocchi di avena · 60 g',
        'Latte · 200 ml',
        'Banana · 100 g',
        'Cacao amaro · 8 g',
      ],
      steps: <String>[
        'Scalda latte e avena.',
        'Aggiungi cacao.',
        'Completa con banana.',
      ],
      tags: <String>['Colazione', 'Vegetariana'],
    ),
  ];

  static const List<MockScaleMeasurement> scaleMeasurements =
      <MockScaleMeasurement>[
    MockScaleMeasurement(
      id: 'scale-2026-06-29',
      dateLabel: '29 giugno 2026 · 08:10',
      weightKg: 63.35,
      bodyFatPercent: 18.4,
      muscleMassKg: 48.6,
      waterPercent: 57.2,
      bmi: 24.7,
      device: 'Bilancia smart',
      reliability: 'Normale',
    ),
    MockScaleMeasurement(
      id: 'scale-2026-06-22',
      dateLabel: '22 giugno 2026 · 08:05',
      weightKg: 63.80,
      bodyFatPercent: 18.8,
      muscleMassKg: 48.7,
      waterPercent: 56.9,
      bmi: 24.9,
      device: 'Bilancia smart',
      reliability: 'Normale',
    ),
  ];

  static const List<MockTapeMeasurement> tapeMeasurements =
      <MockTapeMeasurement>[
    MockTapeMeasurement(
      id: 'tape-2026-06-29',
      dateLabel: '29 giugno 2026 · 08:20',
      entries: <String, double>{
        'Vita': 76.5,
        'Fianchi': 92.0,
        'Torace': 94.0,
        'Braccio destro': 31.2,
        'Coscia destra': 54.0,
      },
      reliability: 'Normale',
      notes: 'Misure prese a riposo.',
    ),
  ];

  static const List<MockRoutine> routines = <MockRoutine>[
    MockRoutine(
      id: 'routine-upper',
      name: 'Upper Body',
      goal: 'Ipertrofia',
      summary: 'Petto, dorso, spalle e braccia.',
      exercises: <MockRoutineExercise>[
        MockRoutineExercise(
          name: 'Panca piana bilanciere',
          mode: 'Palestra',
          sets: 4,
          repetitions: '6–8',
          restSeconds: 120,
          primaryMuscles: <String>['Petto'],
        ),
        MockRoutineExercise(
          name: 'Lat machine',
          mode: 'Palestra',
          sets: 4,
          repetitions: '8–10',
          restSeconds: 105,
          primaryMuscles: <String>['Dorso'],
        ),
        MockRoutineExercise(
          name: 'Alzate laterali',
          mode: 'Palestra',
          sets: 3,
          repetitions: '12–15',
          restSeconds: 75,
          primaryMuscles: <String>['Spalle'],
        ),
      ],
      notes: 'Priorità alla tecnica e progressione graduale.',
    ),
    MockRoutine(
      id: 'routine-cardio',
      name: 'Cardio inclinato',
      goal: 'Condizionamento',
      summary: 'Treadmill con pendenza controllata.',
      exercises: <MockRoutineExercise>[
        MockRoutineExercise(
          name: 'Treadmill inclinato',
          mode: 'Treadmill',
          sets: 1,
          repetitions: '30 minuti',
          restSeconds: 0,
          primaryMuscles: <String>['Gambe'],
        ),
      ],
      notes: 'Target medio: 4,8 km/h e 9% di pendenza.',
    ),
  ];

  static const List<MockWorkoutPlan> plans = <MockWorkoutPlan>[
    MockWorkoutPlan(
      id: 'plan-main',
      name: 'Scheda principale',
      level: 'Intermedio',
      status: 'Attiva',
      days: <MockPlanDay>[
        MockPlanDay(
          title: 'Giorno A · Upper',
          exercises: <String>[
            'Panca piana · 4×6–8',
            'Lat machine · 4×8–10',
            'Alzate laterali · 3×12–15',
          ],
        ),
        MockPlanDay(
          title: 'Giorno B · Lower',
          exercises: <String>[
            'Hip thrust · 4×8–10',
            'Leg curl · 4×10–12',
            'Leg extension · 3×12–15',
          ],
        ),
      ],
      notes: 'Progressione settimanale conservativa.',
    ),
  ];

  static const List<MockWorkoutSession> sessions = <MockWorkoutSession>[
    MockWorkoutSession(
      id: 'session-2026-06-27',
      title: 'Richiamo gambe soft & Treadmill',
      dateLabel: '27 giugno 2026',
      status: 'Completata',
      durationMinutes: 30,
      averageHeartRate: 85,
      estimatedKcal: 125,
      exercises: <MockSessionExercise>[
        MockSessionExercise(
          name: 'Hip Thrust Machine',
          mode: 'Palestra',
          summary: '2 warm-up + 2 serie allenanti',
          completed: true,
        ),
        MockSessionExercise(
          name: 'Leg Curl',
          mode: 'Palestra',
          summary: '2 serie allenanti',
          completed: true,
        ),
        MockSessionExercise(
          name: 'Treadmill',
          mode: 'Treadmill',
          summary: '10 min · pendenza moderata',
          completed: true,
        ),
      ],
      notes: 'Sessione breve, volume totale 4840 kg.',
    ),
    MockWorkoutSession(
      id: 'session-planned',
      title: 'Upper Body',
      dateLabel: '1 luglio 2026',
      status: 'Pianificata',
      durationMinutes: 0,
      averageHeartRate: 0,
      estimatedKcal: 0,
      exercises: <MockSessionExercise>[
        MockSessionExercise(
          name: 'Panca piana bilanciere',
          mode: 'Palestra',
          summary: '4×6–8',
          completed: false,
        ),
        MockSessionExercise(
          name: 'Lat machine',
          mode: 'Palestra',
          summary: '4×8–10',
          completed: false,
        ),
      ],
      notes: '',
    ),
  ];

  static MockDayRecord? dayById(String id) {
    for (final MockDayRecord value in days) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  static MockMeal? mealById(String id) {
    for (final MockMeal value in meals) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  static MockRecipe? recipeById(String id) {
    for (final MockRecipe value in recipes) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  static MockScaleMeasurement? scaleById(String id) {
    for (final MockScaleMeasurement value in scaleMeasurements) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  static MockTapeMeasurement? tapeById(String id) {
    for (final MockTapeMeasurement value in tapeMeasurements) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  static MockRoutine? routineById(String id) {
    for (final MockRoutine value in routines) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  static MockWorkoutPlan? planById(String id) {
    for (final MockWorkoutPlan value in plans) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  static MockWorkoutSession? sessionById(String id) {
    for (final MockWorkoutSession value in sessions) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}
