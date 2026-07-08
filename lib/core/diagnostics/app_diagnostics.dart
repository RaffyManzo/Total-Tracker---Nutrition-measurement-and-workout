import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/transfer/domain/transfer_models.dart';

class AppDiagnosticLogFile {
  const AppDiagnosticLogFile({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int sizeBytes;
}

class AppDiagnosticsStatus {
  const AppDiagnosticsStatus({
    required this.activeDirectory,
    required this.internalDirectory,
    required this.usingCustomDirectory,
    required this.currentLogFile,
    required this.sessionId,
  });

  final String activeDirectory;
  final String internalDirectory;
  final bool usingCustomDirectory;
  final String currentLogFile;
  final String sessionId;
}

class AppDiagnostics {
  AppDiagnostics._();

  static final AppDiagnostics instance = AppDiagnostics._();

  static const String _customDirectoryPreference =
      'diagnostics.custom_directory.v1';
  static const int diagnosticsSchemaVersion = 2;
  static const int objectBoxModelVersion = 1;
  static const int _maxFileBytes = 2 * 1024 * 1024;
  static const Duration _retention = Duration(hours: 24);

  Completer<void> _initialization = Completer<void>();
  Future<void> _writeQueue = Future<void>.value();
  Directory? _internalDirectory;
  Directory? _activeDirectory;
  bool _usingCustomDirectory = false;
  String _sessionId = '';
  String _sessionBaseName = '';
  File? _currentLogFile;
  int _rotation = 0;

  Future<void> initialize({bool startNewSession = false}) async {
    if (_initialization.isCompleted && !startNewSession) {
      return;
    }
    if (startNewSession && _initialization.isCompleted) {
      _initialization = Completer<void>();
    }

    try {
      final Directory support = await getApplicationSupportDirectory();
      _internalDirectory = Directory(
        p.join(support.path, 'total_tracker', 'logs'),
      );
      await _internalDirectory!.create(recursive: true);

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String customPath =
          preferences.getString(_customDirectoryPreference)?.trim() ?? '';

      if (customPath.isNotEmpty) {
        final Directory custom = Directory(customPath);
        try {
          await custom.create(recursive: true);
          await _probeDirectory(custom);
          _activeDirectory = custom;
          _usingCustomDirectory = true;
        } catch (_) {
          _activeDirectory = _internalDirectory;
          _usingCustomDirectory = false;
        }
      } else {
        _activeDirectory = _internalDirectory;
      }

      _beginNewSession();
      await _deleteExpiredLogs();
      if (!_initialization.isCompleted) {
        _initialization.complete();
      }
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      await _writeDirect(
        level: 'info',
        event: 'diagnostics.session_started',
        data: <String, Object?>{
          'sessionId': _sessionId,
          'appVersion': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
          'diagnosticsSchemaVersion': diagnosticsSchemaVersion,
          'transferSchemaVersion': totalTrackerArchiveVersion,
          'objectBoxModelVersion': objectBoxModelVersion,
          'platform': defaultTargetPlatform.name,
          'buildMode': kReleaseMode
              ? 'release'
              : kProfileMode
                  ? 'profile'
                  : 'debug',
          'activeDirectory': _activeDirectory!.path,
          'internalDirectory': _internalDirectory!.path,
          'usingCustomDirectory': _usingCustomDirectory,
        },
      );
    } catch (error, stackTrace) {
      if (!_isExpectedPlatformDirectoryFailure(error)) {
        debugPrint('Total Tracker diagnostics initialization failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      final Directory fallback = Directory(
        p.join(Directory.systemTemp.path, 'total_tracker', 'logs'),
      );
      try {
        await fallback.create(recursive: true);
      } catch (_) {
        // Logging must never prevent application startup.
      }
      _internalDirectory ??= fallback;
      _activeDirectory ??= _internalDirectory;
      _usingCustomDirectory = false;
      _beginNewSession();
      if (!_initialization.isCompleted) {
        _initialization.complete();
      }
    }
  }

  bool _isExpectedPlatformDirectoryFailure(Object error) {
    final String message = error.toString();
    return message.contains('Binding has not yet been initialized') ||
        message.contains('MissingPluginException') ||
        message.contains('getApplicationSupportDirectory');
  }

  Future<AppDiagnosticsStatus> status() async {
    await _ensureInitialized();
    final File file = await _resolveLogFile();
    return AppDiagnosticsStatus(
      activeDirectory: _activeDirectory!.path,
      internalDirectory: _internalDirectory!.path,
      usingCustomDirectory: _usingCustomDirectory,
      currentLogFile: file.path,
      sessionId: _sessionId,
    );
  }

  Future<List<AppDiagnosticLogFile>> listLogFiles() async {
    await _ensureInitialized();
    await _deleteExpiredLogs();
    final Directory directory = _activeDirectory ?? _internalDirectory!;
    if (!await directory.exists()) {
      return const <AppDiagnosticLogFile>[];
    }
    final List<AppDiagnosticLogFile> files = <AppDiagnosticLogFile>[];
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File || !_isLogFile(entity)) {
        continue;
      }
      final FileStat stat = await entity.stat();
      files.add(
        AppDiagnosticLogFile(
          path: entity.path,
          name: p.basename(entity.path),
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
    files.sort(
      (AppDiagnosticLogFile a, AppDiagnosticLogFile b) =>
          b.modifiedAt.compareTo(a.modifiedAt),
    );
    return files;
  }

  Future<String> readLogFile(String path) async {
    await _ensureInitialized();
    final File file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File di log non trovato.', path);
    }
    return file.readAsString();
  }

  Future<String> exportLogAsText({
    required String sourcePath,
    required String targetDirectory,
  }) async {
    await _ensureInitialized();
    final String raw = await readLogFile(sourcePath);
    final Directory directory = Directory(targetDirectory);
    await directory.create(recursive: true);
    await _probeDirectory(directory);

    final String sourceName = p.basenameWithoutExtension(sourcePath);
    final String targetPath = p.join(directory.path, '$sourceName.txt');
    final StringBuffer output = StringBuffer();
    for (final String line in const LineSplitter().convert(raw)) {
      if (line.trim().isEmpty) continue;
      try {
        final Object? decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          output
            ..writeln(
              '[${decoded['timestamp'] ?? ''}] '
              '${(decoded['level'] ?? 'info').toString().toUpperCase()} '
              '${decoded['event'] ?? ''}',
            )
            ..writeln(
                'Dati: ${jsonEncode(decoded['data'] ?? <String, Object?>{})}');
          if (decoded['error'] != null) {
            output.writeln('Errore: ${decoded['error']}');
          }
          if (decoded['stackTrace'] != null) {
            output.writeln('Stack trace:\n${decoded['stackTrace']}');
          }
          output.writeln();
          continue;
        }
      } catch (_) {
        // Preserve malformed lines verbatim in the exported text.
      }
      output.writeln(line);
    }
    await File(targetPath).writeAsString(output.toString(), flush: true);
    return targetPath;
  }

  Future<void> setCustomDirectory(String directoryPath) async {
    await _ensureInitialized();
    final String normalized = directoryPath.trim();
    if (normalized.isEmpty) {
      throw FileSystemException('La cartella selezionata e vuota.');
    }

    final Directory selected = Directory(normalized);
    await selected.create(recursive: true);
    await _probeDirectory(selected);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_customDirectoryPreference, selected.path);
    _activeDirectory = selected;
    _usingCustomDirectory = true;
    _resetCurrentFileForDirectory();

    await info(
      'diagnostics.directory_changed',
      data: <String, Object?>{'directory': selected.path},
    );
  }

  Future<void> resetToInternalDirectory() async {
    await _ensureInitialized();
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_customDirectoryPreference);
    _activeDirectory = _internalDirectory;
    _usingCustomDirectory = false;
    _resetCurrentFileForDirectory();
    await info(
      'diagnostics.directory_reset',
      data: <String, Object?>{'directory': _internalDirectory!.path},
    );
  }

  Future<void> clearLogs() async {
    await _ensureInitialized();
    final List<Directory> directories = <Directory>{
      _internalDirectory!,
      _activeDirectory!,
    }.toList();

    for (final Directory directory in directories) {
      if (!await directory.exists()) continue;
      await for (final FileSystemEntity entity in directory.list()) {
        if (entity is File && _isLogFile(entity)) {
          await entity.delete();
        }
      }
    }
    _resetCurrentFileForDirectory();
    await info('diagnostics.logs_cleared');
  }

  Future<void> writeTestEntry() {
    return info(
      'diagnostics.test_entry',
      data: const <String, Object?>{
        'message': 'Scrittura diagnostica verificata dalle impostazioni.',
      },
    );
  }

  Future<void> info(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _enqueue(level: 'info', event: event, data: data);
  }

  Future<void> warning(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _enqueue(
      level: 'warning',
      event: event,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  Future<void> error(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _enqueue(
      level: 'error',
      event: event,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) {
    final Iterable<DiagnosticsNode>? information =
        details.informationCollector?.call();
    return error(
      'flutter.framework_error',
      error: details.exception,
      stackTrace: details.stack,
      data: <String, Object?>{
        'library': details.library,
        'context': details.context?.toDescription(),
        'silent': details.silent,
        if (information != null)
          'information': information
              .take(30)
              .map((DiagnosticsNode node) => node.toString())
              .toList(),
      },
    );
  }

  Future<T> measure<T>(
    String event,
    Future<T> Function() operation, {
    Map<String, Object?> data = const <String, Object?>{},
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final T value = await operation();
      stopwatch.stop();
      await info(
        '$event.completed',
        data: <String, Object?>{
          ...data,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return value;
    } catch (exception, stackTrace) {
      stopwatch.stop();
      await error(
        '$event.failed',
        error: exception,
        stackTrace: stackTrace,
        data: <String, Object?>{
          ...data,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  T measureSync<T>(
    String event,
    T Function() operation, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final T value = operation();
      stopwatch.stop();
      unawaited(
        info(
          '$event.completed',
          data: <String, Object?>{
            ...data,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        ),
      );
      return value;
    } catch (exception, stackTrace) {
      stopwatch.stop();
      unawaited(
        error(
          '$event.failed',
          error: exception,
          stackTrace: stackTrace,
          data: <String, Object?>{
            ...data,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialization.isCompleted) {
      await initialize();
    }
    await _initialization.future;
  }

  Future<void> _enqueue({
    required String level,
    required String event,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> data = const <String, Object?>{},
  }) async {
    await _ensureInitialized();
    _writeQueue = _writeQueue.then<void>((_) async {
      try {
        await _writeDirect(
          level: level,
          event: event,
          error: error,
          stackTrace: stackTrace,
          data: data,
        );
      } catch (writeError, writeStackTrace) {
        debugPrint('Total Tracker diagnostics write failed: $writeError');
        debugPrintStack(stackTrace: writeStackTrace);
      }
    });
    await _writeQueue;
  }

  Future<void> _writeDirect({
    required String level,
    required String event,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> data = const <String, Object?>{},
  }) async {
    final File file = await _resolveLogFile();
    final Map<String, Object?> record = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'sessionId': _sessionId,
      'level': level,
      'event': event,
      'data': _jsonSafe(data),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
    await file.writeAsString(
      '${jsonEncode(record)}\n',
      mode: FileMode.append,
      flush: level == 'error',
    );
    await _deleteExpiredLogs();
  }

  Future<File> _resolveLogFile() async {
    final Directory directory = _activeDirectory ?? _internalDirectory!;
    await directory.create(recursive: true);

    File? file = _currentLogFile;
    if (file == null || p.dirname(file.path) != directory.path) {
      file = File(p.join(directory.path, '$_sessionBaseName.jsonl'));
      _currentLogFile = file;
    }
    if (await file.exists() && await file.length() >= _maxFileBytes) {
      _rotation += 1;
      file = File(
        p.join(directory.path, '${_sessionBaseName}_part$_rotation.jsonl'),
      );
      _currentLogFile = file;
    }
    return file;
  }

  void _beginNewSession() {
    final DateTime now = DateTime.now().toUtc();
    final String stamp = now
        .toIso8601String()
        .replaceAll(RegExp(r'[-:TZ.]'), '')
        .substring(0, 17);
    _sessionId = '${stamp}_${now.microsecondsSinceEpoch % 1000000}';
    _sessionBaseName = 'total_tracker_session_$_sessionId';
    _rotation = 0;
    _currentLogFile = null;
  }

  void _resetCurrentFileForDirectory() {
    _rotation = 0;
    _currentLogFile = null;
  }

  Future<void> _probeDirectory(Directory directory) async {
    final File probe = File(
      p.join(
        directory.path,
        '.total_tracker_write_probe_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
  }

  bool _isLogFile(FileSystemEntity entity) {
    final String name = p.basename(entity.path);
    return name.startsWith('total_tracker_') && name.endsWith('.jsonl');
  }

  Future<void> _deleteExpiredLogs() async {
    final DateTime cutoff = DateTime.now().subtract(_retention);
    final Set<Directory> directories = <Directory>{
      if (_internalDirectory != null) _internalDirectory!,
      if (_activeDirectory != null) _activeDirectory!,
    };
    for (final Directory directory in directories) {
      if (!await directory.exists()) continue;
      await for (final FileSystemEntity entity in directory.list()) {
        if (entity is! File || !_isLogFile(entity)) continue;
        try {
          final FileStat stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // Cleanup is intentionally fail-soft.
        }
      }
    }
  }

  Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Iterable<Object?>) {
      return value.take(100).map<Object?>(_jsonSafe).toList();
    }
    if (value is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries.take(100))
          entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    return value.toString();
  }
}
