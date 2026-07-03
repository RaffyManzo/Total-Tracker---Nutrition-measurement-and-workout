import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/ingredient_image_storage_service.dart';

void main() {
  group('Ingredient image validation', () {
    test('detects PNG, JPEG and WebP magic bytes', () {
      expect(
        IngredientImageStorageService.detectExtension(
          Uint8List.fromList(<int>[
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A,
          ]),
        ),
        'png',
      );
      expect(
        IngredientImageStorageService.detectExtension(
          Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0x00]),
        ),
        'jpg',
      );
      expect(
        IngredientImageStorageService.detectExtension(
          Uint8List.fromList(<int>[
            0x52,
            0x49,
            0x46,
            0x46,
            0,
            0,
            0,
            0,
            0x57,
            0x45,
            0x42,
            0x50,
          ]),
        ),
        'webp',
      );
    });

    test('rejects content that is not a supported image', () {
      expect(
        () => IngredientImageStorageService.detectExtension(
          Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        ),
        throwsA(isA<IngredientImageStorageException>()),
      );
    });
  });
}
