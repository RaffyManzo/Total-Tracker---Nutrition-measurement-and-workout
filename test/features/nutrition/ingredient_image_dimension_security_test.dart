import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/ingredient_image_storage_service.dart';

void main() {
  Uint8List pngHeader(int width, int height) {
    final Uint8List bytes = Uint8List(24);
    bytes
        .setAll(0, const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    bytes.setAll(12, 'IHDR'.codeUnits);
    bytes[16] = (width >> 24) & 0xff;
    bytes[17] = (width >> 16) & 0xff;
    bytes[18] = (width >> 8) & 0xff;
    bytes[19] = width & 0xff;
    bytes[20] = (height >> 24) & 0xff;
    bytes[21] = (height >> 16) & 0xff;
    bytes[22] = (height >> 8) & 0xff;
    bytes[23] = height & 0xff;
    return bytes;
  }

  Uint8List jpegHeader(int width, int height) {
    return Uint8List.fromList(<int>[
      0xff,
      0xd8,
      0xff,
      0xc0,
      0x00,
      0x11,
      0x08,
      (height >> 8) & 0xff,
      height & 0xff,
      (width >> 8) & 0xff,
      width & 0xff,
      0x03,
      0x01,
      0x11,
      0x00,
      0x02,
      0x11,
      0x00,
      0x03,
      0x11,
      0x00,
      0xff,
      0xd9,
    ]);
  }

  test('accepts bounded PNG dimensions', () {
    expect(
      () => IngredientImageStorageService.validateDimensions(
        pngHeader(4000, 3000),
        extension: 'png',
      ),
      returnsNormally,
    );
  });

  test('rejects excessive PNG dimensions', () {
    expect(
      () => IngredientImageStorageService.validateDimensions(
        pngHeader(9000, 1000),
        extension: 'png',
      ),
      throwsA(isA<IngredientImageStorageException>()),
    );
  });

  test('reads JPEG SOF dimensions and applies pixel limit', () {
    expect(
      () => IngredientImageStorageService.validateDimensions(
        jpegHeader(6000, 4000),
        extension: 'jpg',
      ),
      throwsA(isA<IngredientImageStorageException>()),
    );
  });
}
