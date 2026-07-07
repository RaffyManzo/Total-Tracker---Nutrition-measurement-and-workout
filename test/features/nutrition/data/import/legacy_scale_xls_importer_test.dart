import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/import/legacy_scale_xls_importer.dart';

void main() {
  test('matches localized and partially matching smart-scale headers', () {
    const importer = LegacyScaleXlsImporter();
    final matches = importer.matchHeaders(const <String>[
      'tempo',
      'Peso (kg)',
      'Grasso corporeo %',
      'Massa muscolare',
      'Acqua corporea',
      'Grasso viscerale',
      'Massa ossea',
      'BMR',
      'Età del corpo',
    ]);
    final map = <String, String>{
      for (final match in matches) match.targetField: match.sourceHeader,
    };

    expect(map['dateTime'], 'tempo');
    expect(map['weightKg'], 'Peso (kg)');
    expect(map['bodyFatPercent'], 'Grasso corporeo %');
    expect(map['muscleMassKg'], 'Massa muscolare');
    expect(map['waterPercent'], 'Acqua corporea');
    expect(map['basalMetabolismKcal'], 'BMR');
    expect(map['metabolicAge'], 'Età del corpo');
  });
}
