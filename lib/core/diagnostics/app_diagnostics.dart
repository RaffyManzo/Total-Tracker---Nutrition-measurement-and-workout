import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDiagnosticsStatus {
  const AppDiagnosticsStatus({
    required this.activeDirectory,
    required this.internalDirectory,
    required this.usingCustomDirectory,
    required this.currentLogFile,
  });

  final String activeDirectory;
  final String internalDirectory;
  final bool usingCustomDirectory;
  final String currentLogFile;
}

class AppDiagnostics {
  AppDiagnostics._();

  static final AppDiagnostics instance = AppDiagnostics._();

  static const String _customDirectoryPreference =
      'diagnostics.custom_directory.v1';
  static const int _maxFileBytes = 2 * 1024 * 1024;
  static const int _retainedFileCount = 12;

  final Completer<void> _initialization = Completer<void>();
  Future<void> _writeQueue = Future<void>.value();
  Directory? _internalDirectory;
  Directory? _activeDirectory;
  bool _usingCustomDirectory = false;

  Future<void> initialize() async {
    if (_initialization.isCompleted) return;

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

      _initialization.complete();
      await _writeDirect(
        level: 'info',
        event: 'diagnostics.initialized',
        data: <String, Object?>{
          'activeDirectory': _activeDirectory!.path,
          'internalDirectory': _internalDirectory!.path,
          'usingCustomDirectory': _usingCustomDirectory,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Total Tracker diagnostics initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final Directory fallback = Directory(
        p.join(Directory.systemTemp.path, 'total_tracker', 'logs'),
      );
      try {
        await fallback.create(recursive: true);
      } catch (_) {
        // Anche senza filesystem disponibile l'app deve poter partire.
      }
      _internalDirectory ??= fallback;
      _activeDirectory ??= _internalDirectory;
      _usingCustomDirectory = false;
      if (!_initialization.isCompleted) {
        _initialization.complete();
      }
    }
  }

  Future<AppDiagnosticsStatus> status() async {
    await _ensureInitialized();
    final File file = await _resolveLogFile();
    return AppDiagnosticsStatus(
      activeDirectory: _activeDirectory!.path,
      internalDirectory: _internalDirectory!.path,
      usingCustomDirectory: _usingCustomDirectory,
      currentLogFile: file.path,
    );
  }

  Future<void> setCustomDirectory(String directoryPath) async {
    await _ensureInitialized();
    final String normalized = directoryPath.trim();
    if (normalized.isEmpty) {
      throw FileSystemException('La cartella selezionata è vuota.');
    }

    final Directory selected = Directory(normalized);
    await selected.create(recursive: true);
    await _probeDirectory(selected);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_customDirectoryPreference, selected.path);
    _activeDirectory = selected;
    _usingCustomDirectory = true;

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
        if (entity is File &&
            p.basename(entity.path).startsWith('total_tracker_') &&
            entity.path.endsWith('.jsonl')) {
          await entity.delete();
        }
      }
    }
    await info('diagnostics.logs_cleared');
  }

  Future<void> writeTestEntry() {
    return info(
      'diagnostics.test_entry',
      data: <String, Object?>{
        'message': 'Scrittura diagnostica verificata dalle impostazioni.',
      },
    );
  }

  Future<void> info(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return _enqueue(
      level: 'info',
      event: event,
      data: data,
    );
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
    await _trimOldFiles(file.parent);
  }

  Future<File> _resolveLogFile() async {
    final Directory directory = _activeDirectory ?? _internalDirectory!;
    await directory.create(recursive: true);
    final String day =
        DateTime.now().toUtc().toIso8601String().substring(0, 10);
    File file = File(p.join(directory.path, 'total_tracker_$day.jsonl'));
    if (await file.exists() && await file.length() >= _maxFileBytes) {
      final String suffix =
          DateTime.now().toUtc().millisecondsSinceEpoch.toString();
      file = File(
        p.join(directory.path, 'total_tracker_${day}_$suffix.jsonl'),
      );
    }
    return file;
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

  Future<void> _trimOldFiles(Directory directory) async {
    final List<File> files = <File>[];
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('total_tracker_') &&
          entity.path.endsWith('.jsonl')) {
        files.add(entity);
      }
    }
    if (files.length <= _retainedFileCount) return;
    files.sort((File a, File b) => a.path.compareTo(b.path));
    for (final File file in files.take(files.length - _retainedFileCount)) {
      try {
        await file.delete();
      } catch (_) {
        // La rotazione non deve bloccare il flusso applicativo.
      }
    }
  }

  Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
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
