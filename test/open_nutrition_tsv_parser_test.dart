import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/open_nutrition_tsv_parser.dart';

void main() {
  test('parses supported OpenNutrition-style JSON columns', () {
    final parser = OpenNutritionTsvParser(
      datasetVersion: '2025.1',
      importBatchId: 'batch',
      importedAtEpochMs: 1,
    );
    parser.readHeader(
      'id\tname\tbrand\tbarcode\tnutrition_100g\tsource\tunknown',
    );
    final result = parser.parseRow(
      'food-1\tGreek yogurt\tBrand X\t123\t'
      '"{""energy_kcal"":59,""protein"":10,'
      '""carbohydrates"":3.6,""fat"":0.4}"\t'
      '"{""provider"":""Open Food Facts""}"\tkept',
    );
    expect(result.isValid, isTrue);
    final entity = result.entity!;
    expect(entity.externalFoodId, 'food-1');
    expect(entity.kcalPer100g, 59);
    expect(entity.proteinPer100g, 10);
    expect(entity.fromOpenFoodFacts, isTrue);
    expect(entity.additionalFieldsJson, contains('unknown'));
  });

  test('requires identifier and name columns', () {
    final parser = OpenNutritionTsvParser(
      datasetVersion: '2025.1',
      importBatchId: 'batch',
      importedAtEpochMs: 1,
    );
    expect(
      () => parser.readHeader('brand\tbarcode'),
      throwsA(isA<OpenNutritionSchemaException>()),
    );
  });

  test('TSV parser supports quoted tab and escaped quote', () {
    final values = OpenNutritionTsvParser.parseTsvLine(
      '1\t"name\twith tab"\t"a ""quote"""',
    );
    expect(values, <String>['1', 'name\twith tab', 'a "quote"']);
  });
}
