class MockDayRecord {
  const MockDayRecord({
    required this.id,
    required this.dateLabel,
    required this.weekLabel,
    required this.targetKcal,
    required this.caloriesIn,
    required this.activeKcal,
    required this.steps,
    required this.weightKg,
    required this.waterLiters,
    required this.sleepHours,
    required this.notes,
  });

  final String id;
  final String dateLabel;
  final String weekLabel;
  final double targetKcal;
  final double caloriesIn;
  final double activeKcal;
  final int steps;
  final double weightKg;
  final double waterLiters;
  final double sleepHours;
  final String notes;

  double get balance => caloriesIn - targetKcal;
}

class MockMeal {
  const MockMeal({
    required this.id,
    required this.title,
    required this.mealType,
    required this.dateLabel,
    required this.mode,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.items,
    required this.notes,
  });

  final String id;
  final String title;
  final String mealType;
  final String dateLabel;
  final String mode;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> items;
  final String notes;
}

class MockRecipe {
  const MockRecipe({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.servings,
    required this.totalMinutes,
    required this.difficulty,
    required this.kcalPerServing,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    required this.ingredients,
    required this.steps,
    required this.tags,
  });

  final String id;
  final String title;
  final String subtitle;
  final int servings;
  final int totalMinutes;
  final String difficulty;
  final double kcalPerServing;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tags;
}

class MockScaleMeasurement {
  const MockScaleMeasurement({
    required this.id,
    required this.dateLabel,
    required this.weightKg,
    required this.bodyFatPercent,
    required this.muscleMassKg,
    required this.waterPercent,
    required this.bmi,
    required this.device,
    required this.reliability,
  });

  final String id;
  final String dateLabel;
  final double weightKg;
  final double bodyFatPercent;
  final double muscleMassKg;
  final double waterPercent;
  final double bmi;
  final String device;
  final String reliability;
}

class MockTapeMeasurement {
  const MockTapeMeasurement({
    required this.id,
    required this.dateLabel,
    required this.entries,
    required this.reliability,
    required this.notes,
  });

  final String id;
  final String dateLabel;
  final Map<String, double> entries;
  final String reliability;
  final String notes;
}

class MockRoutine {
  const MockRoutine({
    required this.id,
    required this.name,
    required this.goal,
    required this.summary,
    required this.exercises,
    required this.notes,
  });

  final String id;
  final String name;
  final String goal;
  final String summary;
  final List<MockRoutineExercise> exercises;
  final String notes;
}

class MockRoutineExercise {
  const MockRoutineExercise({
    required this.name,
    required this.mode,
    required this.sets,
    required this.repetitions,
    required this.restSeconds,
    required this.primaryMuscles,
  });

  final String name;
  final String mode;
  final int sets;
  final String repetitions;
  final int restSeconds;
  final List<String> primaryMuscles;
}

class MockWorkoutPlan {
  const MockWorkoutPlan({
    required this.id,
    required this.name,
    required this.level,
    required this.status,
    required this.days,
    required this.notes,
  });

  final String id;
  final String name;
  final String level;
  final String status;
  final List<MockPlanDay> days;
  final String notes;
}

class MockPlanDay {
  const MockPlanDay({
    required this.title,
    required this.exercises,
  });

  final String title;
  final List<String> exercises;
}

class MockWorkoutSession {
  const MockWorkoutSession({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.status,
    required this.durationMinutes,
    required this.averageHeartRate,
    required this.estimatedKcal,
    required this.exercises,
    required this.notes,
  });

  final String id;
  final String title;
  final String dateLabel;
  final String status;
  final int durationMinutes;
  final int averageHeartRate;
  final double estimatedKcal;
  final List<MockSessionExercise> exercises;
  final String notes;
}

class MockSessionExercise {
  const MockSessionExercise({
    required this.name,
    required this.mode,
    required this.summary,
    required this.completed,
  });

  final String name;
  final String mode;
  final String summary;
  final bool completed;
}
