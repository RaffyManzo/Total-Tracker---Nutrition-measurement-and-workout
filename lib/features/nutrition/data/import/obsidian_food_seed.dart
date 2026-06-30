import 'dart:convert';

class ObsidianFoodSeedConstants {
  const ObsidianFoodSeedConstants._();

  static const String schemaVersion = 'obsidian-food-seed-v1';
  static const String defaultAssetPath =
      'assets/dev_seed/obsidian_food_2026-06-22_2026-06-30.json';
  static const List<String> mealSlots = <String>[
    'colazione',
    'spuntino',
    'pranzo',
    'cena',
  ];
}

class MealNutritionTotals {
  const MealNutritionTotals({
    required this.kcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.sugarGrams,
  });

  final double kcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double fiberGrams;
  final double sugarGrams;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kcal': _round(kcal),
      'proteinGrams': _round(proteinGrams),
      'carbsGrams': _round(carbsGrams),
      'fatGrams': _round(fatGrams),
      'fiberGrams': _round(fiberGrams),
      'sugarGrams': _round(sugarGrams),
    };
  }

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}

class ObsidianFoodSeedMapper {
  const ObsidianFoodSeedMapper();

  bool isWithinInclusive(String dateKey, String from, String to) {
    final DateTime? date = parseDate(dateKey);
    final DateTime? fromDate = parseDate(from);
    final DateTime? toDate = parseDate(to);
    if (date == null || fromDate == null || toDate == null) {
      return false;
    }
    return !date.isBefore(fromDate) && !date.isAfter(toDate);
  }

  Map<String, dynamic> normalizeDay(
    Map<String, dynamic> frontmatter, {
    required String relativePath,
  }) {
    final String? fallbackDate = _dateFromPath(relativePath);
    final String dateKey = readDate(frontmatter['date']) ?? fallbackDate ?? '';
    return <String, dynamic>{
      'uuid': 'obsidian-day:$dateKey',
      'relativePath': relativePath,
      'date': dateKey,
      'week': readString(frontmatter['week']),
      'weekday_key': readString(frontmatter['weekday_key']),
      'weekday_label': readString(frontmatter['weekday_label']),
      'weekday_index': readInt(frontmatter['weekday_index']),
      'target_kcal': readDouble(frontmatter['target_kcal']),
      'target_status': readString(frontmatter['target_status']),
      'target_calculated_at': readString(frontmatter['target_calculated_at']),
      'target_source_hash': readString(frontmatter['target_source_hash']),
      'tdee_ref_kcal': readDouble(frontmatter['tdee_ref_kcal']),
      'tdee_theoretical_kcal': readDouble(frontmatter['tdee_theoretical_kcal']),
      'tdee_observed_kcal': readDouble(frontmatter['tdee_observed_kcal']),
      'observed_confidence': readDouble(frontmatter['observed_confidence']),
      'reference_days_count': readInt(frontmatter['reference_days_count']),
      'valid_intake_days': readInt(frontmatter['valid_intake_days']),
      'valid_weight_days': readInt(frontmatter['valid_weight_days']),
      'rmr_kcal': readDouble(frontmatter['rmr_kcal']),
      'weight_ref_kg': readDouble(frontmatter['weight_ref_kg']),
      'active_ref_kcal': readDouble(frontmatter['active_ref_kcal']),
      'active_kcal_steps': readDouble(frontmatter['active_kcal_steps']),
      'active_kcal_workout_completed':
          readDouble(frontmatter['active_kcal_workout_completed']),
      'active_kcal_workout_in_progress':
          readDouble(frontmatter['active_kcal_workout_in_progress']),
      'active_kcal_workout_planned':
          readDouble(frontmatter['active_kcal_workout_planned']),
      'active_kcal_workout_skipped':
          readDouble(frontmatter['active_kcal_workout_skipped']),
      'active_kcal_workout_unknown':
          readDouble(frontmatter['active_kcal_workout_unknown']),
      'active_kcal_actual': readDouble(frontmatter['active_kcal_actual']),
      'active_effective_kcal': readDouble(frontmatter['active_effective_kcal']),
      'activity_delta_kcal': readDouble(frontmatter['activity_delta_kcal']),
      'active_status': readString(frontmatter['active_status']),
      'calories_in_kcal': readDouble(frontmatter['calories_in_kcal']),
      'energy_balance_kcal': readDouble(frontmatter['energy_balance_kcal']),
      'weight_kg': readDouble(frontmatter['weight_kg']) ??
          readDouble(frontmatter['peso']),
      'peso': readDouble(frontmatter['peso']),
      'weight_reliability': readString(frontmatter['weight_reliability']),
      'free_meal_mode': readString(frontmatter['free_meal_mode']),
      'free_meal_kcal': readDouble(frontmatter['free_meal_kcal']),
      'free_meal_reliability': readString(frontmatter['free_meal_reliability']),
      'data_completeness_score':
          readDouble(frontmatter['data_completeness_score']),
      'water_l': readDouble(frontmatter['water_l']),
      'water_glasses': readInt(frontmatter['water_glasses']),
      'sleep_deep_h': readDouble(frontmatter['sleep_deep_h']),
      'sleep_light_h': readDouble(frontmatter['sleep_light_h']),
      'sleep_quality': readString(frontmatter['sleep_quality']),
      'steps': readInt(frontmatter['steps']),
      'step_goal': readInt(frontmatter['step_goal']),
      'notes': readString(frontmatter['notes']),
      'activity_bonus_kcal': readDouble(frontmatter['activity_bonus_kcal']),
    };
  }

  Map<String, dynamic> normalizeMeal(
    Map<String, dynamic> frontmatter, {
    required String relativePath,
  }) {
    final String? fallbackDate = _dateFromPath(relativePath);
    final String dateKey = readDate(frontmatter['date']) ?? fallbackDate ?? '';
    final String stem = relativePath
        .split('/')
        .last
        .replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
    final String mealUuid = 'obsidian-meal:${_slug(stem)}';
    final List<dynamic> rawFoods =
        frontmatter['foods'] is List<dynamic> ? frontmatter['foods'] : const [];
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];

    for (int index = 0; index < rawFoods.length; index += 1) {
      final dynamic rawItem = rawFoods[index];
      if (rawItem is! Map<String, dynamic>) {
        continue;
      }
      items
          .add(normalizeMealItem(rawItem, mealUuid: mealUuid, position: index));
    }

    final String mode = readString(frontmatter['meal_mode']).isEmpty
        ? 'standard'
        : readString(frontmatter['meal_mode']);
    return <String, dynamic>{
      'uuid': mealUuid,
      'relativePath': relativePath,
      'week': readString(frontmatter['week']),
      'date': dateKey,
      'weekday_key': readString(frontmatter['weekday_key']),
      'weekday_label': readString(frontmatter['weekday_label']),
      'meal_type': readString(frontmatter['meal_type']),
      'title': readString(frontmatter['title']),
      'meal_mode': mode,
      'free_meal_tracking': readString(frontmatter['free_meal_tracking']),
      'free_meal_label': readString(frontmatter['free_meal_label']),
      'free_meal_notes': readString(frontmatter['free_meal_notes']),
      'items': items,
      'isNutritionPartial': isMealNutritionPartial(
        mode,
        readString(frontmatter['free_meal_tracking']),
        items,
      ),
      'totals': totalItems(items).toJson(),
    };
  }

  Map<String, dynamic> normalizeMealItem(
    Map<String, dynamic> rawItem, {
    required String mealUuid,
    required int position,
  }) {
    final String kind = readString(rawItem['kind']).isEmpty
        ? 'manual_estimate'
        : readString(rawItem['kind']);
    final double? grams = readDouble(rawItem['grams']);
    final double? portions = readDouble(rawItem['portions']);
    return <String, dynamic>{
      'uuid': 'obsidian-meal-item:$mealUuid:$position',
      'mealUuid': mealUuid,
      'position': position,
      'kind': kind,
      'source': normalizeSource(readString(rawItem['source'])),
      'item_name': readString(rawItem['item_name']),
      'quantity_mode': grams != null ? 'grams' : 'portions',
      'grams': grams,
      'portions': portions,
      'kcal': readDouble(rawItem['kcal']) ?? 0,
      'protein_g': readDouble(rawItem['protein_g']) ?? 0,
      'carbs_g': readDouble(rawItem['carbs_g']) ?? 0,
      'fat_g': readDouble(rawItem['fat_g']) ?? 0,
      'fiber_g': readDouble(rawItem['fiber_g']) ?? 0,
      'sugar_g': readDouble(rawItem['sugar_g']) ?? 0,
      'notes': readString(rawItem['notes']),
    };
  }

  MealNutritionTotals totalItems(List<Map<String, dynamic>> items) {
    double kcal = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double fiber = 0;
    double sugar = 0;
    for (final Map<String, dynamic> item in items) {
      kcal += readDouble(item['kcal']) ?? 0;
      protein += readDouble(item['protein_g']) ?? 0;
      carbs += readDouble(item['carbs_g']) ?? 0;
      fat += readDouble(item['fat_g']) ?? 0;
      fiber += readDouble(item['fiber_g']) ?? 0;
      sugar += readDouble(item['sugar_g']) ?? 0;
    }
    return MealNutritionTotals(
      kcal: kcal,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      fiberGrams: fiber,
      sugarGrams: sugar,
    );
  }

  bool isMealNutritionPartial(
    String mealMode,
    String freeMealTracking,
    List<Map<String, dynamic>> items,
  ) {
    if (mealMode != 'free') {
      return false;
    }
    if (freeMealTracking == 'untracked') {
      return true;
    }
    if (freeMealTracking == 'estimated') {
      return items.any((Map<String, dynamic> item) {
        return readString(item['kind']) == 'manual_estimate' &&
            ((readDouble(item['kcal']) ?? 0) <= 0);
      });
    }
    return false;
  }

  String normalizeSource(String source) {
    String normalized = source.trim();
    if (normalized.startsWith('[[') && normalized.endsWith(']]')) {
      normalized = normalized.substring(2, normalized.length - 2);
    }
    final int aliasIndex = normalized.indexOf('|');
    if (aliasIndex >= 0) {
      normalized = normalized.substring(0, aliasIndex);
    }
    normalized = normalized.replaceAll('\\', '/').trim();
    const String prefix = 'Food planning and monitoring/';
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length);
    }
    return normalized;
  }

  String readString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    return value.toString().trim();
  }

  double? readDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final String text = value.toString().trim().replaceAll(',', '.');
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
  }

  int? readInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    final double? parsed = readDouble(value);
    return parsed?.round();
  }

  String? readDate(dynamic value) {
    final String raw = readString(value);
    if (raw.isEmpty) {
      return null;
    }
    final RegExpMatch? match = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return parseDate(match.group(1)!)?.toIso8601String().split('T').first;
  }

  DateTime? parseDate(String value) {
    final RegExpMatch? match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  Map<String, dynamic> decodeSeed(String jsonText) {
    final dynamic decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Seed JSON must contain an object root.');
    }
    return decoded;
  }

  String? _dateFromPath(String relativePath) {
    final RegExpMatch? match =
        RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(relativePath);
    if (match == null) {
      return null;
    }
    return readDate(match.group(1));
  }

  String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
