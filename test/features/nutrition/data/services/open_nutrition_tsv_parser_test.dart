import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/open_nutrition_tsv_parser.dart';

void main() {
  group('OpenNutritionTsvRecordDecoder', () {
    test('preserves quoted tabs, newlines and escaped quotes across chunks', () async {
      final chunks = Stream<String>.fromIterable(<String>[
        '\uFEFFid\tname\tdescription\n1\t"Pasta\t',
        'integrale"\t"Linea uno\nLinea ""due"""\n',
      ]);
      final rows = await const OpenNutritionTsvRecordDecoder()
          .bind(chunks)
          .toList();
      expect(rows, hasLength(2));
      expect(rows[1][1], 'Pasta\tintegrale');
      expect(rows[1][2], 'Linea uno\nLinea "due"');
    });
  });

  group('OpenNutritionTsvParser', () {
    late OpenNutritionTsvParser parser;

    setUp(() {
      parser = OpenNutritionTsvParser(
        datasetVersion: 'test',
        importBatchId: 'batch',
        importedAtEpochMs: 1,
      );
      parser.readHeaderRecord(<String>[
        'id',
        'name',
        'alternate_names',
        'description',
        'nutrition_100g',
        'ean_13',
        'source',
        'image_url',
      ]);
    });

    test('maps official fields, nested nutrients, ean_13 and image', () {
      final row = parser.parseRecord(<String>[
        'food-1',
        'Yogurt bianco',
        '["Yoghurt"]',
        'Naturale',
        '{"energy-kcal":{"value":61,"unit":"kcal"},'
            '"proteins_100g":3.5,"carbohydrates_100g":4.7,'
            '"fat_100g":3.3}',
        '8001234567890',
        '{"provider":"Open Food Facts"}',
        'https://example.test/yogurt.jpg',
      ]);

      expect(row.entity, isNotNull);
      expect(row.entity!.name, 'Yogurt bianco');
      expect(row.entity!.barcode, '8001234567890');
      expect(row.entity!.kcalPer100g, 61);
      expect(row.entity!.proteinPer100g, 3.5);
      expect(row.entity!.hasCompleteMacros, isTrue);
      expect(row.entity!.fromOpenFoodFacts, isTrue);
      expect(row.entity!.imageUrl, 'https://example.test/yogurt.jpg');
    });

    test('converts kJ only when the unit explicitly states kJ', () {
      final row = parser.parseRecord(<String>[
        'food-2',
        'Riso',
        '[]',
        '',
        '{"energy":{"value":418.4,"unit":"kJ"}}',
        '',
        '{}',
        '',
      ]);
      expect(row.entity!.kcalPer100g, closeTo(100, 0.01));
    });

    test('rejects a JSON object used as the name', () {
      final row = parser.parseRecord(<String>[
        'food-3',
        '{"name":"raw","nutrition_100g":{}}',
        '[]',
        '',
        '{}',
        '',
        '{}',
        '',
      ]);
      expect(row.entity, isNull);
    });

    test('uses a scalar alternate name when the main name is invalid', () {
      final row = parser.parseRecord(<String>[
        'food-4',
        '[{"raw":true}]',
        '["Mela"]',
        '',
        '{}',
        '',
        '{}',
        '',
      ]);
      expect(row.entity!.name, 'Mela');
    });
  });
}
