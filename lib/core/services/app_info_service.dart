import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../database/objectbox_providers.dart';

class AppInfoSnapshot {
  const AppInfoSnapshot({
    required this.version,
    required this.buildNumber,
    required this.filesDirectory,
    required this.objectBoxDirectory,
    required this.localDataBytes,
    required this.objectBoxBytes,
  });

  final String version;
  final String buildNumber;
  final String filesDirectory;
  final String objectBoxDirectory;
  final int localDataBytes;
  final int objectBoxBytes;

  String get versionLabel {
    if (buildNumber.trim().isEmpty) {
      return version;
    }
    return '$version+$buildNumber';
  }
}

final FutureProvider<AppInfoSnapshot> appInfoProvider =
    FutureProvider<AppInfoSnapshot>((Ref ref) async {
  final String? objectBoxDirectory =
      ref.watch(objectBoxDatabaseProvider).directory;
  return const AppInfoService().load(
    objectBoxDirectory: objectBoxDirectory,
  );
});

class AppInfoService {
  const AppInfoService();

  Future<AppInfoSnapshot> load({String? objectBoxDirectory}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final Directory filesDirectory = await getApplicationDocumentsDirectory();
    final int localDataBytes = await calculateDirectorySize(filesDirectory);
    final String resolvedObjectBoxDirectory = objectBoxDirectory ?? '';
    final int objectBoxBytes = resolvedObjectBoxDirectory.isEmpty
        ? 0
        : await calculateDirectorySize(Directory(resolvedObjectBoxDirectory));

    return AppInfoSnapshot(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      filesDirectory: filesDirectory.path,
      objectBoxDirectory: resolvedObjectBoxDirectory,
      localDataBytes: localDataBytes,
      objectBoxBytes: objectBoxBytes,
    );
  }

  static Future<int> calculateDirectorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }
    int total = 0;
    try {
      await for (final FileSystemEntity entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } on FileSystemException {
            // Un file temporaneamente non leggibile non deve bloccare la pagina.
          }
        }
      }
    } on FileSystemException {
      return total;
    }
    return total;
  }
}

String formatAppByteSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final double kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(kib < 10 ? 1 : 0)} KB';
  }
  final double mib = kib / 1024;
  if (mib < 1024) {
    return '${mib.toStringAsFixed(mib < 10 ? 1 : 0)} MB';
  }
  final double gib = mib / 1024;
  return '${gib.toStringAsFixed(2)} GB';
}
