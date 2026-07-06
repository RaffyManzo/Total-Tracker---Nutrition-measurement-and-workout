import 'food_analytics_service.dart';

class TdeeReliabilityComponent {
  const TdeeReliabilityComponent({
    required this.code,
    required this.label,
    required this.earnedPoints,
    required this.maximumPoints,
    required this.explanation,
  });

  final String code;
  final String label;
  final double earnedPoints;
  final double maximumPoints;
  final String explanation;
}

/// Auditable engineering score for the evidence supporting observed TDEE.
///
/// This 0-100 score is intentionally separate from the model's statistical
/// blending confidence. It communicates data coverage, freshness and whether
/// activity was observed or estimated; it is not a clinical measurement.
class TdeeReliabilityScore {
  const TdeeReliabilityScore({
    required this.total,
    required this.bandCode,
    required this.bandLabel,
    required this.components,
  });

  final double total;
  final String bandCode;
  final String bandLabel;
  final List<TdeeReliabilityComponent> components;

  bool get hasObservedTdee => components.any(
        (TdeeReliabilityComponent item) =>
            item.code == 'observed_tdee' && item.earnedPoints > 0,
      );

  static TdeeReliabilityScore fromTarget(TargetDayResult result) {
    final List<TdeeReliabilityComponent> components =
        <TdeeReliabilityComponent>[
      _ratioComponent(
        code: 'reference_window',
        label: 'Copertura finestra storica',
        value: result.referenceDaysCount,
        target: 28,
        maximum: 15,
        explanation:
            '${result.referenceDaysCount} giorni disponibili sui 28 di riferimento.',
      ),
      _ratioComponent(
        code: 'intake_days',
        label: 'Giorni alimentari utilizzabili',
        value: result.validIntakeDays,
        target: 14,
        maximum: 25,
        explanation:
            '${result.validIntakeDays} giorni con apporto energetico utilizzabile.',
      ),
      _ratioComponent(
        code: 'weight_days',
        label: 'Campioni di peso utilizzabili',
        value: result.validWeightDays,
        target: 8,
        maximum: 20,
        explanation:
            '${result.validWeightDays} misurazioni valide contribuiscono al trend.',
      ),
      _weightFreshness(result),
      _observedEvidence(result),
      _activityFidelity(result),
    ];

    final double total = components
        .fold<double>(
          0,
          (double sum, TdeeReliabilityComponent item) =>
              sum + item.earnedPoints,
        )
        .clamp(0, 100)
        .toDouble();
    final String bandCode;
    final String bandLabel;
    if (total >= 80) {
      bandCode = 'high';
      bandLabel = 'Alta';
    } else if (total >= 60) {
      bandCode = 'good';
      bandLabel = 'Buona';
    } else if (total >= 40) {
      bandCode = 'moderate';
      bandLabel = 'Moderata';
    } else {
      bandCode = 'low';
      bandLabel = 'Bassa';
    }

    return TdeeReliabilityScore(
      total: total,
      bandCode: bandCode,
      bandLabel: bandLabel,
      components: List<TdeeReliabilityComponent>.unmodifiable(components),
    );
  }

  static TdeeReliabilityComponent _ratioComponent({
    required String code,
    required String label,
    required int value,
    required int target,
    required double maximum,
    required String explanation,
  }) {
    final double ratio =
        target <= 0 ? 0.0 : (value / target).clamp(0, 1).toDouble();
    return TdeeReliabilityComponent(
      code: code,
      label: label,
      earnedPoints: maximum * ratio,
      maximumPoints: maximum,
      explanation: explanation,
    );
  }

  static TdeeReliabilityComponent _weightFreshness(TargetDayResult result) {
    final int? age = result.weightDaysSinceMeasurement;
    final double points = age == null
        ? 0.0
        : 15.0 * (1.0 - (age.clamp(0, 20) / 20.0)).clamp(0, 1).toDouble();
    return TdeeReliabilityComponent(
      code: 'weight_freshness',
      label: 'Recenza del peso',
      earnedPoints: points,
      maximumPoints: 15,
      explanation: age == null
          ? 'Nessuna misurazione del peso databile disponibile.'
          : 'Ultima misurazione utile: $age giorni fa.',
    );
  }

  static TdeeReliabilityComponent _observedEvidence(
    TargetDayResult result,
  ) {
    final bool observed = result.tdeeObservedKcal != null;
    final bool trend = result.deltaWeightKg != null;
    final double confidenceContribution = observed
        ? 3 * (result.observedConfidence / 0.8).clamp(0, 1).toDouble()
        : 0;
    final double points =
        (observed ? 5.0 : 0.0) + (trend ? 2.0 : 0.0) + confidenceContribution;
    return TdeeReliabilityComponent(
      code: 'observed_tdee',
      label: 'TDEE osservato e trend peso',
      earnedPoints: points,
      maximumPoints: 10,
      explanation: observed
          ? 'Componente osservata disponibile; trend peso '
              '${trend ? 'disponibile' : 'incompleto'}; confidenza del modello '
              '${(result.observedConfidence * 100).round()}%.'
          : 'La componente osservata non è ancora calcolabile.',
    );
  }

  static TdeeReliabilityComponent _activityFidelity(TargetDayResult result) {
    final String status = result.activity.statusCode;
    final double points = switch (status) {
      'actual' => 15,
      'mixed' => 10,
      'estimated' => 5,
      _ => 0,
    };
    final String explanation = switch (status) {
      'actual' => 'Passi e attività del giorno provengono da dati effettivi.',
      'mixed' => 'Il giorno combina dati effettivi e valori previsionali.',
      'estimated' => 'L’attività del giorno è prevalentemente stimata.',
      _ => 'Attività non disponibile per il giorno.',
    };
    return TdeeReliabilityComponent(
      code: 'activity_fidelity',
      label: 'Qualità dei dati di attività',
      earnedPoints: points,
      maximumPoints: 15,
      explanation: explanation,
    );
  }
}
