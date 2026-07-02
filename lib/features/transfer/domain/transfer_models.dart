import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const String totalTrackerArchiveFormat = 'total-tracker-portable';
const int totalTrackerArchiveVersion = 1;

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

  Uint8List encode(TransferArchivePayload payload) {
    final List<int> manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload.manifest),
    );
    final List<int> dataBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload.data),
    );
    final Map<String, dynamic> checksums = <String, dynamic>{
      'algorithm': 'fnv1a32',
      'manifest.json': _fnv1a32(manifestBytes),
      'data.json': _fnv1a32(dataBytes),
    };
    final List<int> checksumBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(checksums),
    );

    final Archive archive = Archive()
      ..addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      )
      ..addFile(ArchiveFile('data.json', dataBytes.length, dataBytes))
      ..addFile(
        ArchiveFile('checksums.json', checksumBytes.length, checksumBytes),
      );
    final List<int> encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  TransferArchivePayload decode(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object catch (error) {
      throw FormatException('Archivio non leggibile: $error');
    }

    final Map<String, List<int>> files = <String, List<int>>{};
    for (final ArchiveFile file in archive) {
      if (!file.isFile) {
        continue;
      }
      files[file.name] = file.content;
    }

    final List<int>? manifestBytes = files['manifest.json'];
    final List<int>? dataBytes = files['data.json'];
    if (manifestBytes == null || dataBytes == null) {
      throw const FormatException(
        'Il file non contiene manifest.json e data.json.',
      );
    }

    final Map<String, dynamic> manifest = _decodeMap(manifestBytes);
    final Map<String, dynamic> data = _decodeMap(dataBytes);

    if (manifest['format'] != totalTrackerArchiveFormat) {
      throw const FormatException('Formato Total Tracker non riconosciuto.');
    }
    final int version = _asInt(manifest['formatVersion']) ?? 0;
    if (version <= 0 || version > totalTrackerArchiveVersion) {
      throw FormatException('Versione archivio non supportata: $version.');
    }

    final List<int>? checksumBytes = files['checksums.json'];
    if (checksumBytes != null) {
      final Map<String, dynamic> checksumMap = _decodeMap(checksumBytes);
      final String expectedManifest =
          checksumMap['manifest.json']?.toString() ?? '';
      final String expectedData = checksumMap['data.json']?.toString() ?? '';
      if (expectedManifest.isNotEmpty &&
          expectedManifest != _fnv1a32(manifestBytes)) {
        throw const FormatException('Checksum manifest non valido.');
      }
      if (expectedData.isNotEmpty && expectedData != _fnv1a32(dataBytes)) {
        throw const FormatException('Checksum dati non valido.');
      }
    }

    return TransferArchivePayload(manifest: manifest, data: data);
  }

  Map<String, dynamic> _decodeMap(List<int> bytes) {
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('JSON radice non valido.');
    }
    return decoded.map<String, dynamic>(
      (Object? key, Object? value) => MapEntry<String, dynamic>(
        key.toString(),
        value,
      ),
    );
  }

  String _fnv1a32(List<int> bytes) {
    int hash = 0x811c9dc5;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  int? _asInt(Object? value) {
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
