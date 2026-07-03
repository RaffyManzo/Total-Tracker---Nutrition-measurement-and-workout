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
