import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/nutrition_tracking_entities.dart';

class TargetInputHasher {
  const TargetInputHasher._();

  static const String version = 'target-input-v1';

  static String hashForDay({
    required DailyRecordEntity day,
    required Iterable<DailyRecordEntity> chronologicalHistory,
    required String modelVersion,
    String? inputRevisionSeed,
  }) {
    final List<Map<String, Object?>> history = chronologicalHistory
        .where((item) => item.dateKey.compareTo(day.dateKey) <= 0)
        .map(_dayInputMap)
        .toList(growable: false)
      ..sort((a, b) => (a['dateKey']! as String).compareTo(
            b['dateKey']! as String,
          ));
    final Map<String, Object?> canonical = <String, Object?>{
      'hashVersion': version,
      'modelVersion': modelVersion,
      'dateKey': day.dateKey,
      'inputRevisionSeed': inputRevisionSeed ?? '',
      'day': _dayInputMap(day),
      'history': history,
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static Map<String, Object?> _dayInputMap(DailyRecordEntity day) {
    return <String, Object?>{
      'dateKey': day.dateKey,
      'steps': day.steps,
      'stepGoal': day.stepGoal,
      'weightKg': _number(day.weightKg),
      'freeMealModeCode': day.freeMealModeCode,
      'freeMealKcal': _number(day.freeMealKcal),
      'deleted': day.deletedAtEpochMs != null,
    };
  }

  static String? _number(double? value) {
    if (value == null || !value.isFinite) return null;
    return value.toStringAsFixed(6);
  }
}
