import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class IngredientImageStorageException implements Exception {
  const IngredientImageStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class IngredientImageStorageService {
  const IngredientImageStorageService._();

  static const int maximumBytes = 8 * 1024 * 1024;
  static const int maximumDimension = 8192;
  static const int maximumPixels = 20 * 1000 * 1000;

  static Future<String> persist({
    required Uint8List bytes,
    required String originalName,
  }) async {
    if (bytes.isEmpty) {
      throw const IngredientImageStorageException(
        'Il file immagine è vuoto.',
      );
    }
    if (bytes.length > maximumBytes) {
      throw const IngredientImageStorageException(
        'L’immagine supera il limite di 8 MB.',
      );
    }

    final String extension = detectExtension(bytes);
    validateDimensions(bytes, extension: extension);
    final String declaredExtension =
        path.extension(originalName).toLowerCase().replaceFirst('.', '');
    if (declaredExtension.isNotEmpty &&
        !_compatibleExtensions(extension, declaredExtension)) {
      throw const IngredientImageStorageException(
        'Il contenuto del file non corrisponde alla sua estensione.',
      );
    }

    final Directory support = await getApplicationSupportDirectory();
    final Directory directory =
        Directory(path.join(support.path, 'ingredient_images'));
    await directory.create(recursive: true);

    final String fileName = '${const Uuid().v4()}.$extension';
    final File target = File(path.join(directory.path, fileName));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  static String validateRemoteImageUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const IngredientImageStorageException(
        'L’URL immagine deve usare HTTPS e non contenere credenziali.',
      );
    }

    final String host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.contains('..') ||
        _looksLikeIpLiteral(host) ||
        !RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
      throw const IngredientImageStorageException(
        'Host immagine non consentito.',
      );
    }
    return uri.toString();
  }

  static String detectExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    throw const IngredientImageStorageException(
      'Formato non supportato. Usa PNG, JPEG o WebP.',
    );
  }

  static void validateDimensions(
    Uint8List bytes, {
    String? extension,
  }) {
    final String actualExtension = extension ?? detectExtension(bytes);
    final List<int> dimensions;
    switch (actualExtension) {
      case 'png':
        dimensions = _pngDimensions(bytes);
      case 'jpg':
        dimensions = _jpegDimensions(bytes);
      case 'webp':
        dimensions = _webpDimensions(bytes);
      default:
        throw const IngredientImageStorageException(
          'Formato immagine non supportato.',
        );
    }
    final int width = dimensions[0];
    final int height = dimensions[1];
    if (width <= 0 ||
        height <= 0 ||
        width > maximumDimension ||
        height > maximumDimension ||
        width * height > maximumPixels) {
      throw const IngredientImageStorageException(
        'Le dimensioni dell’immagine superano i limiti di sicurezza.',
      );
    }
  }

  static List<int> _pngDimensions(Uint8List bytes) {
    if (bytes.length < 24 ||
        String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') {
      throw const IngredientImageStorageException(
        'Intestazione PNG non valida.',
      );
    }
    return <int>[
      _readUint32BigEndian(bytes, 16),
      _readUint32BigEndian(bytes, 20),
    ];
  }

  static List<int> _jpegDimensions(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) {
      throw const IngredientImageStorageException(
        'Intestazione JPEG non valida.',
      );
    }
    var offset = 2;
    while (offset + 3 < bytes.length) {
      while (offset < bytes.length && bytes[offset] != 0xff) {
        offset += 1;
      }
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset += 1;
      }
      if (offset >= bytes.length) break;
      final int marker = bytes[offset];
      offset += 1;
      if (marker == 0xd8 ||
          marker == 0xd9 ||
          marker == 0x01 ||
          (marker >= 0xd0 && marker <= 0xd7)) {
        continue;
      }
      if (offset + 1 >= bytes.length) break;
      final int segmentLength = _readUint16BigEndian(bytes, offset);
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        break;
      }
      if (_isJpegStartOfFrame(marker)) {
        if (segmentLength < 7) break;
        final int height = _readUint16BigEndian(bytes, offset + 3);
        final int width = _readUint16BigEndian(bytes, offset + 5);
        return <int>[width, height];
      }
      offset += segmentLength;
    }
    throw const IngredientImageStorageException(
      'Dimensioni JPEG non leggibili.',
    );
  }

  static bool _isJpegStartOfFrame(int marker) {
    return <int>{
      0xc0,
      0xc1,
      0xc2,
      0xc3,
      0xc5,
      0xc6,
      0xc7,
      0xc9,
      0xca,
      0xcb,
      0xcd,
      0xce,
      0xcf,
    }.contains(marker);
  }

  static List<int> _webpDimensions(Uint8List bytes) {
    if (bytes.length < 25 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WEBP') {
      throw const IngredientImageStorageException(
        'Intestazione WebP non valida.',
      );
    }
    final String chunk = String.fromCharCodes(bytes.sublist(12, 16));
    if (chunk == 'VP8X') {
      if (bytes.length < 30) {
        throw const IngredientImageStorageException(
          'Intestazione WebP VP8X troncata.',
        );
      }
      return <int>[
        1 + _readUint24LittleEndian(bytes, 24),
        1 + _readUint24LittleEndian(bytes, 27),
      ];
    }
    if (chunk == 'VP8 ') {
      if (bytes.length < 30 ||
          bytes[23] != 0x9d ||
          bytes[24] != 0x01 ||
          bytes[25] != 0x2a) {
        throw const IngredientImageStorageException(
          'Intestazione WebP VP8 non valida.',
        );
      }
      return <int>[
        _readUint16LittleEndian(bytes, 26) & 0x3fff,
        _readUint16LittleEndian(bytes, 28) & 0x3fff,
      ];
    }
    if (chunk == 'VP8L') {
      if (bytes[20] != 0x2f) {
        throw const IngredientImageStorageException(
          'Intestazione WebP VP8L non valida.',
        );
      }
      final int bits =
          bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
      return <int>[
        (bits & 0x3fff) + 1,
        ((bits >> 14) & 0x3fff) + 1,
      ];
    }
    throw const IngredientImageStorageException(
      'Formato interno WebP non supportato.',
    );
  }

  static int _readUint16BigEndian(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 1 >= bytes.length) {
      throw const IngredientImageStorageException(
        'Intestazione immagine troncata.',
      );
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  static int _readUint16LittleEndian(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 1 >= bytes.length) {
      throw const IngredientImageStorageException(
        'Intestazione immagine troncata.',
      );
    }
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static int _readUint24LittleEndian(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 2 >= bytes.length) {
      throw const IngredientImageStorageException(
        'Intestazione immagine troncata.',
      );
    }
    return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
  }

  static int _readUint32BigEndian(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 3 >= bytes.length) {
      throw const IngredientImageStorageException(
        'Intestazione immagine troncata.',
      );
    }
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static bool _compatibleExtensions(String actual, String declared) {
    if (actual == declared) return true;
    return actual == 'jpg' && declared == 'jpeg';
  }

  static bool _looksLikeIpLiteral(String host) {
    if (host.contains(':')) return true;
    final List<String> parts = host.split('.');
    if (parts.length != 4) return false;
    for (final String part in parts) {
      final int? value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
    }
    return true;
  }
}
