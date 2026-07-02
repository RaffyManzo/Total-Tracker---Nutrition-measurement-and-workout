import 'dart:convert';

import '../../profile/data/entities/user_profile_entity.dart';
import '../../profile/domain/profile_codes.dart';

class MealNutrientTarget {
  const MealNutrientTarget({
    this.kcal,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
  });

  static const MealNutrientTarget empty = MealNutrientTarget();

  final double? kcal;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;

  bool get hasAny =>
      kcal != null ||
      proteinGrams != null ||
      carbsGrams != null ||
      fatGrams != null;

  MealNutrientTarget normalized() {
    return MealNutrientTarget(
      kcal: _positiveOrNull(kcal),
      proteinGrams: _positiveOrNull(proteinGrams),
      carbsGrams: _positiveOrNull(carbsGrams),
      fatGrams: _positiveOrNull(fatGrams),
    );
  }

  Map<String, double> toJson() {
    final MealNutrientTarget clean = normalized();
    return <String, double>{
      if (clean.kcal != null) 'kcal': clean.kcal!,
      if (clean.proteinGrams != null) 'proteinGrams': clean.proteinGrams!,
      if (clean.carbsGrams != null) 'carbsGrams': clean.carbsGrams!,
      if (clean.fatGrams != null) 'fatGrams': clean.fatGrams!,
    };
  }

  factory MealNutrientTarget.fromJson(Object? value) {
    if (value is! Map) {
      return empty;
    }
    return MealNutrientTarget(
      kcal: _number(value['kcal']),
      proteinGrams: _number(value['proteinGrams']),
      carbsGrams: _number(value['carbsGrams']),
      fatGrams: _number(value['fatGrams']),
    ).normalized();
  }

  static double? _number(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  static double? _positiveOrNull(double? value) {
    if (value == null || !value.isFinite || value <= 0) {
      return null;
    }
    return value;
  }
}

class MealTargetSettings {
  const MealTargetSettings({
    required this.modeCode,
    this.sharedTarget = MealNutrientTarget.empty,
    this.slotTargets = const <String, MealNutrientTarget>{},
  });

  final String modeCode;
  final MealNutrientTarget sharedTarget;
  final Map<String, MealNutrientTarget> slotTargets;

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
      final Object? rawSlots = decoded['slots'];
      final Map<String, MealNutrientTarget> slots =
          <String, MealNutrientTarget>{};
      if (rawSlots is Map) {
        for (final MapEntry<Object?, Object?> entry in rawSlots.entries) {
          final String slot = entry.key?.toString() ?? '';
          if (supportedSlots.contains(slot)) {
            slots[slot] = MealNutrientTarget.fromJson(entry.value);
          }
        }
      }
      return MealTargetSettings(
        modeCode: mode,
        sharedTarget: MealNutrientTarget.fromJson(decoded['shared']),
        slotTargets: slots,
      );
    } on FormatException {
      return MealTargetSettings(modeCode: mode);
    }
  }

  MealNutrientTarget effectiveTargetForSlot(String slotCode) {
    if (modeCode == MealTargetModeCodes.shared) {
      return sharedTarget.normalized();
    }
    if (modeCode == MealTargetModeCodes.custom) {
      return (slotTargets[slotCode] ?? MealNutrientTarget.empty).normalized();
    }
    return MealNutrientTarget.empty;
  }

  String toJsonString() {
    return jsonEncode(<String, Object>{
      'shared': sharedTarget.toJson(),
      'slots': <String, Object>{
        for (final MapEntry<String, MealNutrientTarget> entry
            in slotTargets.entries)
          if (supportedSlots.contains(entry.key))
            entry.key: entry.value.toJson(),
      },
    });
  }

  static const List<String> supportedSlots = <String>[
    'colazione',
    'spuntino',
    'pranzo',
    'cena',
  ];
}
