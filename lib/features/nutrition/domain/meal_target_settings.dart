import 'dart:convert';

import '../../profile/data/entities/user_profile_entity.dart';
import '../../profile/domain/profile_codes.dart';

class MealNutrientPercentages {
  const MealNutrientPercentages({
    this.kcalPercent,
    this.proteinPercent,
    this.carbsPercent,
    this.fatPercent,
    this.fiberPercent,
    this.sugarPercent,
  });

  static const MealNutrientPercentages empty = MealNutrientPercentages();
  static const MealNutrientPercentages uniform = MealNutrientPercentages(
    kcalPercent: 25,
    proteinPercent: 25,
    carbsPercent: 25,
    fatPercent: 25,
    fiberPercent: 25,
    sugarPercent: 25,
  );

  final double? kcalPercent;
  final double? proteinPercent;
  final double? carbsPercent;
  final double? fatPercent;
  final double? fiberPercent;
  final double? sugarPercent;

  bool get hasAny =>
      kcalPercent != null ||
      proteinPercent != null ||
      carbsPercent != null ||
      fatPercent != null ||
      fiberPercent != null ||
      sugarPercent != null;

  bool get isComplete =>
      kcalPercent != null &&
      proteinPercent != null &&
      carbsPercent != null &&
      fatPercent != null &&
      fiberPercent != null &&
      sugarPercent != null;

  bool get isWithinBounds => values.every(
        (double? value) => value != null && value >= 0 && value <= 100,
      );

  List<double?> get values => <double?>[
        kcalPercent,
        proteinPercent,
        carbsPercent,
        fatPercent,
        fiberPercent,
        sugarPercent,
      ];

  double? valueFor(String metricCode) {
    return switch (metricCode) {
      MealTargetMetricCodes.kcal => kcalPercent,
      MealTargetMetricCodes.protein => proteinPercent,
      MealTargetMetricCodes.carbs => carbsPercent,
      MealTargetMetricCodes.fat => fatPercent,
      MealTargetMetricCodes.fiber => fiberPercent,
      MealTargetMetricCodes.sugar => sugarPercent,
      _ => null,
    };
  }

  Map<String, double> toJson() {
    return <String, double>{
      if (_validPercent(kcalPercent)) 'kcalPercent': kcalPercent!,
      if (_validPercent(proteinPercent)) 'proteinPercent': proteinPercent!,
      if (_validPercent(carbsPercent)) 'carbsPercent': carbsPercent!,
      if (_validPercent(fatPercent)) 'fatPercent': fatPercent!,
      if (_validPercent(fiberPercent)) 'fiberPercent': fiberPercent!,
      if (_validPercent(sugarPercent)) 'sugarPercent': sugarPercent!,
    };
  }

  factory MealNutrientPercentages.fromJson(Object? value) {
    if (value is! Map) {
      return empty;
    }
    return MealNutrientPercentages(
      kcalPercent: _percent(value['kcalPercent']),
      proteinPercent: _percent(value['proteinPercent']),
      carbsPercent: _percent(value['carbsPercent']),
      fatPercent: _percent(value['fatPercent']),
      fiberPercent: _percent(value['fiberPercent']),
      sugarPercent: _percent(value['sugarPercent']),
    );
  }

  static double? _percent(Object? value) {
    final double? parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
    if (!_validPercent(parsed)) {
      return null;
    }
    return parsed;
  }

  static bool _validPercent(double? value) {
    return value != null && value.isFinite && value >= 0 && value <= 100;
  }
}

class MealNutrientTarget {
  const MealNutrientTarget({
    this.kcal,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.fiberGrams,
    this.sugarGrams,
    this.percentages = MealNutrientPercentages.empty,
  });

  static const MealNutrientTarget empty = MealNutrientTarget();

  final double? kcal;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
  final double? fiberGrams;
  final double? sugarGrams;
  final MealNutrientPercentages percentages;

  bool get hasAny =>
      kcal != null ||
      proteinGrams != null ||
      carbsGrams != null ||
      fatGrams != null ||
      fiberGrams != null ||
      sugarGrams != null;
}

class MealTargetDistributionTotals {
  const MealTargetDistributionTotals({
    required this.kcalPercent,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
    required this.fiberPercent,
    required this.sugarPercent,
  });

  final double kcalPercent;
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;
  final double fiberPercent;
  final double sugarPercent;

  double valueFor(String metricCode) {
    return switch (metricCode) {
      MealTargetMetricCodes.kcal => kcalPercent,
      MealTargetMetricCodes.protein => proteinPercent,
      MealTargetMetricCodes.carbs => carbsPercent,
      MealTargetMetricCodes.fat => fatPercent,
      MealTargetMetricCodes.fiber => fiberPercent,
      MealTargetMetricCodes.sugar => sugarPercent,
      _ => 0,
    };
  }
}

class MealTargetSettings {
  const MealTargetSettings({
    required this.modeCode,
    this.slotPercentages = const <String, MealNutrientPercentages>{},
  });

  final String modeCode;
  final Map<String, MealNutrientPercentages> slotPercentages;

  factory MealTargetSettings.fromProfile(UserProfileEntity profile) {
    final String mode = MealTargetModeCodes.values.contains(
      profile.mealTargetModeCode,
    )
        ? profile.mealTargetModeCode
        : MealTargetModeCodes.none;
    try {
      final Object? decoded = jsonDecode(profile.mealTargetsJson);
      if (decoded is! Map) {
        return MealTargetSettings(modeCode: mode);
      }
      final Object? version = decoded['version'];
      if (version != 2 && mode == MealTargetModeCodes.custom) {
        return const MealTargetSettings(
          modeCode: MealTargetModeCodes.custom,
          slotPercentages: <String, MealNutrientPercentages>{
            'colazione': MealNutrientPercentages.uniform,
            'spuntino': MealNutrientPercentages.uniform,
            'pranzo': MealNutrientPercentages.uniform,
            'cena': MealNutrientPercentages.uniform,
          },
        );
      }
      final Object? rawSlots = decoded['slots'];
      final Map<String, MealNutrientPercentages> slots =
          <String, MealNutrientPercentages>{};
      if (rawSlots is Map) {
        for (final MapEntry<Object?, Object?> entry in rawSlots.entries) {
          final String slot = entry.key?.toString() ?? '';
          if (supportedSlots.contains(slot)) {
            slots[slot] = MealNutrientPercentages.fromJson(entry.value);
          }
        }
      }
      return MealTargetSettings(modeCode: mode, slotPercentages: slots);
    } on FormatException {
      return MealTargetSettings(modeCode: mode);
    }
  }

  MealNutrientPercentages effectivePercentagesForSlot(String slotCode) {
    if (!supportedSlots.contains(slotCode)) {
      return MealNutrientPercentages.empty;
    }
    if (modeCode == MealTargetModeCodes.shared) {
      return MealNutrientPercentages.uniform;
    }
    if (modeCode == MealTargetModeCodes.custom) {
      return slotPercentages[slotCode] ?? MealNutrientPercentages.empty;
    }
    return MealNutrientPercentages.empty;
  }

  MealNutrientTarget targetForSlot({
    required String slotCode,
    required double dailyKcal,
    required double dailyProteinGrams,
    required double dailyCarbsGrams,
    required double dailyFatGrams,
    required double dailyFiberGrams,
    required double dailySugarGrams,
  }) {
    final MealNutrientPercentages percentages =
        effectivePercentagesForSlot(slotCode);
    if (!percentages.isComplete || !percentages.isWithinBounds) {
      return MealNutrientTarget.empty;
    }
    return MealNutrientTarget(
      kcal: _share(dailyKcal, percentages.kcalPercent),
      proteinGrams: _share(
        dailyProteinGrams,
        percentages.proteinPercent,
      ),
      carbsGrams: _share(dailyCarbsGrams, percentages.carbsPercent),
      fatGrams: _share(dailyFatGrams, percentages.fatPercent),
      fiberGrams: _share(dailyFiberGrams, percentages.fiberPercent),
      sugarGrams: _share(dailySugarGrams, percentages.sugarPercent),
      percentages: percentages,
    );
  }

  MealTargetDistributionTotals distributionTotals() {
    double totalFor(String metricCode) {
      if (modeCode == MealTargetModeCodes.shared) {
        return 100;
      }
      if (modeCode != MealTargetModeCodes.custom) {
        return 0;
      }
      return supportedSlots.fold<double>(
        0,
        (double sum, String slot) =>
            sum + (slotPercentages[slot]?.valueFor(metricCode) ?? 0),
      );
    }

    return MealTargetDistributionTotals(
      kcalPercent: totalFor(MealTargetMetricCodes.kcal),
      proteinPercent: totalFor(MealTargetMetricCodes.protein),
      carbsPercent: totalFor(MealTargetMetricCodes.carbs),
      fatPercent: totalFor(MealTargetMetricCodes.fat),
      fiberPercent: totalFor(MealTargetMetricCodes.fiber),
      sugarPercent: totalFor(MealTargetMetricCodes.sugar),
    );
  }

  String? validationMessage() {
    if (modeCode == MealTargetModeCodes.none ||
        modeCode == MealTargetModeCodes.shared) {
      return null;
    }
    if (modeCode != MealTargetModeCodes.custom) {
      return 'Modalità di distribuzione non valida.';
    }
    for (final String slot in supportedSlots) {
      final MealNutrientPercentages percentages =
          slotPercentages[slot] ?? MealNutrientPercentages.empty;
      if (!percentages.isComplete || !percentages.isWithinBounds) {
        return 'Compila tutte le percentuali di ogni pasto con valori tra 0 e 100.';
      }
    }
    final MealTargetDistributionTotals totals = distributionTotals();
    for (final String metric in MealTargetMetricCodes.values) {
      final double total = totals.valueFor(metric);
      if ((total - 100).abs() > 0.01) {
        return 'La somma di ${MealTargetMetricCodes.label(metric).toLowerCase()} deve essere 100% (ora ${_formatPercent(total)}%).';
      }
    }
    return null;
  }

  String toJsonString() {
    return jsonEncode(<String, Object>{
      'version': 2,
      'slots': <String, Object>{
        for (final String slot in supportedSlots)
          if (slotPercentages.containsKey(slot))
            slot: slotPercentages[slot]!.toJson(),
      },
    });
  }

  static double? _share(double dailyValue, double? percent) {
    if (!dailyValue.isFinite || dailyValue <= 0 || percent == null) {
      return null;
    }
    return dailyValue * percent / 100;
  }

  static String _formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static const List<String> supportedSlots = <String>[
    'colazione',
    'spuntino',
    'pranzo',
    'cena',
  ];
}

class MealTargetMetricCodes {
  const MealTargetMetricCodes._();

  static const String kcal = 'kcal';
  static const String protein = 'protein';
  static const String carbs = 'carbs';
  static const String fat = 'fat';
  static const String fiber = 'fiber';
  static const String sugar = 'sugar';

  static const List<String> values = <String>[
    kcal,
    protein,
    carbs,
    fat,
    fiber,
    sugar,
  ];

  static String label(String code) {
    return switch (code) {
      kcal => 'Calorie',
      protein => 'Proteine',
      carbs => 'Carboidrati',
      fat => 'Grassi',
      fiber => 'Fibre',
      sugar => 'Zuccheri',
      _ => code,
    };
  }
}
