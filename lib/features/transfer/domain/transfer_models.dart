import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const String totalTrackerArchiveFormat = 'total-tracker-portable';
const int totalTrackerArchiveVersion = 2;
const int totalTrackerMaxCompressedArchiveBytes = 32 * 1024 * 1024;
const int totalTrackerMaxEntryBytes = 24 * 1024 * 1024;
const int totalTrackerMaxExpandedArchiveBytes = 32 * 1024 * 1024;
const int totalTrackerMaxArchiveEntries = 3;
const int totalTrackerMaxJsonDepth = 64;
const int totalTrackerMaxJsonNodes = 500000;

enum TransferArea { profile, food, workout }

enum TransferConflictResolution { overwrite, keepExisting, importCopy }

class TransferExportOptions {
  const TransferExportOptions({
    this.includeProfile = true,
    this.includeFood = true,
    this.includeWorkout = true,
  });

  final bool includeProfile;
  final bool includeFood;
  final bool includeWorkout;

  bool get isEmpty => !includeProfile && !includeFood && !includeWorkout;

  List<String> get areaCodes => <String>[
        if (includeProfile) 'profile',
        if (includeFood) 'food',
        if (includeWorkout) 'workout',
      ];
}

class TransferArchivePayload {
  const TransferArchivePayload({
    required this.manifest,
    required this.data,
  });

  final Map<String, dynamic> manifest;
  final Map<String, dynamic> data;
}

class TransferArchiveCodec {
  const TransferArchiveCodec();

  static const Set<String> _allowedEntries = <String>{
    'manifest.json',
    'data.json',
    'checksums.json',
  };

  Uint8List encode(TransferArchivePayload payload) {
    final List<int> manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload.manifest),
    );
    final List<int> dataBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload.data),
    );
    _validateEntrySize('manifest.json', manifestBytes.length);
    _validateEntrySize('data.json', dataBytes.length);

    final Map<String, dynamic> checksums = <String, dynamic>{
      'algorithm': 'sha256',
      'manifest.json': sha256.convert(manifestBytes).toString(),
      'data.json': sha256.convert(dataBytes).toString(),
    };
    final List<int> checksumBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(checksums),
    );

    final Archive archive = Archive()
      ..addFile(
          ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
      ..addFile(ArchiveFile('data.json', dataBytes.length, dataBytes))
      ..addFile(
        ArchiveFile('checksums.json', checksumBytes.length, checksumBytes),
      );
    final List<int> encoded = ZipEncoder().encode(archive);
    if (encoded.length > totalTrackerMaxCompressedArchiveBytes) {
      throw const FormatException(
        'L’archivio generato supera il limite di sicurezza consentito.',
      );
    }
    return Uint8List.fromList(encoded);
  }

  TransferArchivePayload decode(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Archivio vuoto.');
    }
    if (bytes.length > totalTrackerMaxCompressedArchiveBytes) {
      throw const FormatException(
        'Archivio troppo grande per essere importato in sicurezza.',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object catch (error) {
      throw FormatException('Archivio ZIP non valido: $error');
    }
    if (archive.length > totalTrackerMaxArchiveEntries) {
      throw const FormatException('Archivio con troppe voci.');
    }

    final Map<String, List<int>> entries = <String, List<int>>{};
    var expandedBytes = 0;
    for (final ArchiveFile file in archive) {
      if (!file.isFile) {
        throw FormatException('Directory non consentita: ${file.name}');
      }
      final String name = file.name;
      if (!_isSafeEntryName(name) || !_allowedEntries.contains(name)) {
        throw FormatException('Voce non consentita nell’archivio: $name');
      }
      if (entries.containsKey(name)) {
        throw FormatException('Voce duplicata nell’archivio: $name');
      }
      _validateEntrySize(name, file.size);
      expandedBytes += file.size;
      if (expandedBytes > totalTrackerMaxExpandedArchiveBytes) {
        throw const FormatException(
          'Archivio espanso oltre il limite di sicurezza consentito.',
        );
      }
      final Object rawContent = file.content;
      if (rawContent is! List<int>) {
        throw FormatException('Contenuto non valido per la voce: $name');
      }
      final List<int> content = List<int>.unmodifiable(rawContent);
      if (content.length != file.size) {
        throw FormatException('Dimensione incoerente per la voce: $name');
      }
      entries[name] = content;
    }

    final List<int> manifestBytes = _requiredEntry(entries, 'manifest.json');
    final List<int> dataBytes = _requiredEntry(entries, 'data.json');
    final Map<String, dynamic> manifest = _decodeJsonMap(
      manifestBytes,
      'manifest.json',
    );
    if (manifest['format'] != totalTrackerArchiveFormat) {
      throw const FormatException('Formato Total Tracker non riconosciuto.');
    }
    final int version = _asInt(manifest['formatVersion']) ?? 0;
    if (version < 1 || version > totalTrackerArchiveVersion) {
      throw FormatException('Versione archivio non supportata: $version.');
    }

    final List<int>? checksumBytes = entries['checksums.json'];
    if (checksumBytes == null) {
      throw const FormatException('File checksums.json obbligatorio mancante.');
    }
    final Map<String, dynamic> checksumJson = _decodeJsonMap(
      checksumBytes,
      'checksums.json',
    );
    _verifyChecksums(
      version: version,
      checksums: checksumJson,
      manifestBytes: manifestBytes,
      dataBytes: dataBytes,
    );

    final Map<String, dynamic> data = _decodeJsonMap(dataBytes, 'data.json');
    return TransferArchivePayload(manifest: manifest, data: data);
  }

  static bool _isSafeEntryName(String name) {
    return name.isNotEmpty &&
        name != '.' &&
        name != '..' &&
        !name.contains('/') &&
        !name.contains(r'\') &&
        !name.contains('\u0000');
  }

  static List<int> _requiredEntry(
    Map<String, List<int>> entries,
    String name,
  ) {
    final List<int>? value = entries[name];
    if (value == null) {
      throw FormatException('File obbligatorio mancante: $name');
    }
    return value;
  }

  static void _validateEntrySize(String name, int size) {
    if (size <= 0) {
      throw FormatException('Voce vuota non consentita: $name');
    }
    if (size > totalTrackerMaxEntryBytes) {
      throw FormatException('Voce troppo grande: $name');
    }
  }

  static Map<String, dynamic> _decodeJsonMap(
    List<int> bytes,
    String name,
  ) {
    _validateJsonNesting(bytes, name);
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on Object catch (error) {
      throw FormatException('JSON non valido in $name: $error');
    }
    if (decoded is! Map) {
      throw FormatException('La radice JSON di $name deve essere un oggetto.');
    }
    _validateJsonTree(decoded);
    return decoded.map<String, dynamic>(
      (Object? key, Object? value) => MapEntry<String, dynamic>(
        key.toString(),
        value,
      ),
    );
  }

  static void _validateJsonNesting(List<int> bytes, String name) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (final int byte in bytes) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (byte == 0x5c) {
          escaped = true;
        } else if (byte == 0x22) {
          inString = false;
        }
        continue;
      }
      if (byte == 0x22) {
        inString = true;
      } else if (byte == 0x7b || byte == 0x5b) {
        depth += 1;
        if (depth > totalTrackerMaxJsonDepth) {
          throw FormatException('JSON troppo annidato in $name.');
        }
      } else if (byte == 0x7d || byte == 0x5d) {
        depth -= 1;
        if (depth < 0) {
          throw FormatException('Struttura JSON non valida in $name.');
        }
      } else if (byte == 0) {
        throw FormatException('Byte nullo non consentito in $name.');
      }
    }
    if (inString || escaped || depth != 0) {
      throw FormatException('Struttura JSON incompleta in $name.');
    }
  }

  static void _validateJsonTree(Object? root) {
    var nodes = 0;
    void visit(Object? value, int depth) {
      nodes += 1;
      if (nodes > totalTrackerMaxJsonNodes) {
        throw const FormatException('JSON con troppi elementi.');
      }
      if (depth > totalTrackerMaxJsonDepth) {
        throw const FormatException('JSON troppo annidato.');
      }
      if (value is Map) {
        for (final MapEntry<Object?, Object?> entry in value.entries) {
          if (entry.key is! String) {
            throw const FormatException('Chiave JSON non testuale.');
          }
          visit(entry.value, depth + 1);
        }
      } else if (value is List) {
        for (final Object? element in value) {
          visit(element, depth + 1);
        }
      } else if (value is! String &&
          value is! num &&
          value is! bool &&
          value != null) {
        throw const FormatException('Tipo JSON non supportato.');
      }
    }

    visit(root, 0);
  }

  static void _verifyChecksums({
    required int version,
    required Map<String, dynamic> checksums,
    required List<int> manifestBytes,
    required List<int> dataBytes,
  }) {
    final String algorithm =
        checksums['algorithm']?.toString().toLowerCase() ?? '';
    if (version >= 2) {
      if (algorithm != 'sha256') {
        throw FormatException('Algoritmo checksum non supportato: $algorithm');
      }
      _verifyDigest(
        name: 'manifest.json',
        expected: checksums['manifest.json']?.toString(),
        actual: sha256.convert(manifestBytes).toString(),
      );
      _verifyDigest(
        name: 'data.json',
        expected: checksums['data.json']?.toString(),
        actual: sha256.convert(dataBytes).toString(),
      );
      return;
    }

    if (algorithm != 'fnv1a32') {
      throw FormatException(
          'Algoritmo checksum legacy non supportato: $algorithm');
    }
    _verifyDigest(
      name: 'manifest.json',
      expected: checksums['manifest.json']?.toString(),
      actual: _legacyFnv1a32(manifestBytes),
    );
    _verifyDigest(
      name: 'data.json',
      expected: checksums['data.json']?.toString(),
      actual: _legacyFnv1a32(dataBytes),
    );
  }

  static void _verifyDigest({
    required String name,
    required String? expected,
    required String actual,
  }) {
    final String normalized = expected?.toLowerCase() ?? '';
    if (normalized.length != actual.length ||
        !normalized.codeUnits.every(_isLowerHexCodeUnit) ||
        !_constantTimeEquals(normalized, actual)) {
      throw FormatException('Checksum non valido per $name.');
    }
  }

  static bool _isLowerHexCodeUnit(int value) {
    return (value >= 0x30 && value <= 0x39) || (value >= 0x61 && value <= 0x66);
  }

  static bool _constantTimeEquals(String left, String right) {
    final List<int> leftBytes = utf8.encode(left.toLowerCase());
    final List<int> rightBytes = utf8.encode(right.toLowerCase());
    var difference = leftBytes.length ^ rightBytes.length;
    final int maxLength = leftBytes.length > rightBytes.length
        ? leftBytes.length
        : rightBytes.length;
    for (var index = 0; index < maxLength; index += 1) {
      final int leftByte = index < leftBytes.length ? leftBytes[index] : 0;
      final int rightByte = index < rightBytes.length ? rightBytes[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }

  static String _legacyFnv1a32(List<int> bytes) {
    var hash = 0x811c9dc5;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class TransferImportItem {
  TransferImportItem({
    required this.id,
    required this.categoryCode,
    required this.title,
    required this.subtitle,
    required this.data,
    this.selected = true,
    this.hasConflict = false,
    this.conflictDescription = '',
    this.resolution = TransferConflictResolution.overwrite,
  });

  final String id;
  final String categoryCode;
  final String title;
  final String subtitle;
  final Map<String, dynamic> data;
  bool selected;
  final bool hasConflict;
  final String conflictDescription;
  TransferConflictResolution resolution;
}

class TransferImportSection {
  TransferImportSection({
    required this.code,
    required this.title,
    required this.description,
    required this.items,
    this.isProfileSection = false,
  });

  final String code;
  final String title;
  final String description;
  final List<TransferImportItem> items;
  final bool isProfileSection;

  int get selectedCount =>
      items.where((TransferImportItem item) => item.selected).length;
  int get conflictCount =>
      items.where((TransferImportItem item) => item.hasConflict).length;
}

class TransferImportAnalysis {
  TransferImportAnalysis({
    required this.sourcePath,
    required this.manifest,
    required this.sections,
    required this.warnings,
  });

  final String sourcePath;
  final Map<String, dynamic> manifest;
  final List<TransferImportSection> sections;
  final List<String> warnings;

  int get totalItems => sections.fold<int>(
        0,
        (int total, TransferImportSection section) =>
            total + section.items.length,
      );
  int get selectedItems => sections.fold<int>(
        0,
        (int total, TransferImportSection section) =>
            total + section.selectedCount,
      );
  int get conflicts => sections.fold<int>(
        0,
        (int total, TransferImportSection section) =>
            total + section.conflictCount,
      );
}

class TransferExportResult {
  const TransferExportResult({
    required this.path,
    required this.counts,
    required this.bytes,
  });

  final String path;
  final Map<String, int> counts;
  final int bytes;
}

class TransferImportResult {
  const TransferImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
  });

  final int created;
  final int updated;
  final int skipped;

  int get total => created + updated + skipped;
}
