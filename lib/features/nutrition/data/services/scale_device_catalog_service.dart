import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/composition_reliability.dart';

class ScaleDeviceOption {
  const ScaleDeviceOption({
    required this.id,
    required this.name,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.isDefault = false,
    this.isArchived = false,
    this.aliases = const <String>[],
  });

  final String id;
  final String name;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final bool isDefault;
  final bool isArchived;
  final List<String> aliases;

  ScaleDeviceOption copyWith({
    String? name,
    int? updatedAtEpochMs,
    bool? isDefault,
    bool? isArchived,
    List<String>? aliases,
  }) {
    return ScaleDeviceOption(
      id: id,
      name: name ?? this.name,
      createdAtEpochMs: createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      aliases: aliases ?? this.aliases,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'createdAtEpochMs': createdAtEpochMs,
        'updatedAtEpochMs': updatedAtEpochMs,
        'isDefault': isDefault,
        'isArchived': isArchived,
        'aliases': aliases,
      };

  static ScaleDeviceOption fromJson(Map<String, Object?> json) {
    final List<String> aliases = (json['aliases'] is List)
        ? (json['aliases']! as List)
            .map((Object? value) => value.toString())
            .where((String value) => value.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final int created =
        int.tryParse((json['createdAtEpochMs'] ?? '0').toString()) ?? 0;
    return ScaleDeviceOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      createdAtEpochMs: created,
      updatedAtEpochMs:
          int.tryParse((json['updatedAtEpochMs'] ?? created).toString()) ??
              created,
      isDefault: json['isDefault'] == true,
      isArchived: json['isArchived'] == true,
      aliases: List<String>.unmodifiable(aliases),
    );
  }
}

class ScaleDeviceCatalogService {
  ScaleDeviceCatalogService(this._preferences, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const String storageKey = 'scale_device_catalog_v2';
  static const String legacyStorageKey = 'scale_device_catalog_v1';
  static const String tokenPrefix = 'ttdev:';
  static const int schemaVersion = 2;

  final SharedPreferences _preferences;
  final Uuid _uuid;

  List<ScaleDeviceOption> load() {
    return loadAll()
        .where((ScaleDeviceOption item) => !item.isArchived)
        .toList(growable: false);
  }

  List<ScaleDeviceOption> loadAll() {
    final String? rawV2 = _preferences.getString(storageKey);
    if (rawV2 != null && rawV2.trim().isNotEmpty) {
      return _decodeV2(rawV2);
    }
    final String? legacy = _preferences.getString(legacyStorageKey);
    if (legacy == null || legacy.trim().isEmpty) {
      return const <ScaleDeviceOption>[];
    }
    return _normalizeDefaults(_decodeLegacy(legacy));
  }

  Future<void> ensureMigrated() async {
    if (_preferences.getString(storageKey)?.trim().isNotEmpty == true) {
      return;
    }
    final List<ScaleDeviceOption> migrated = loadAll();
    if (migrated.isNotEmpty) {
      await _save(migrated);
    }
  }

  Future<void> mergeStoredValues(Iterable<String> values) async {
    await ensureMigrated();
    final List<ScaleDeviceOption> items = loadAll().toList();
    final Set<String> knownIds = items.map((item) => item.id).toSet();
    final Set<String> knownCanonicalNames = <String>{
      for (final ScaleDeviceOption item in items) _canonical(item.name),
      for (final ScaleDeviceOption item in items)
        for (final String alias in item.aliases) _canonical(alias),
    };
    bool changed = false;
    for (final String value in values) {
      final String name = displayName(value).trim();
      final String canonicalName = _canonical(name);
      if (name.isEmpty ||
          canonicalName == 'unspecified' ||
          canonicalName == 'mixed') {
        continue;
      }
      String id = tokenId(value);
      if (id.isEmpty) {
        id = _uuid.v4();
      }
      if (knownIds.contains(id) ||
          knownCanonicalNames.contains(canonicalName)) {
        continue;
      }
      final int now = DateTime.now().millisecondsSinceEpoch;
      items.add(
        ScaleDeviceOption(
          id: id,
          name: name,
          createdAtEpochMs: now,
          updatedAtEpochMs: now,
          isDefault: items.where((item) => !item.isArchived).isEmpty,
        ),
      );
      knownIds.add(id);
      knownCanonicalNames.add(canonicalName);
      changed = true;
    }
    if (changed) {
      await _save(_normalizeDefaults(items));
    }
  }

  Future<ScaleDeviceOption> add(
    String name, {
    bool makeDefault = false,
  }) async {
    await ensureMigrated();
    final String clean = _cleanName(name);
    if (clean.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Il nome del dispositivo è vuoto.');
    }
    final List<ScaleDeviceOption> items = loadAll().toList();
    final String canonical = _canonical(clean);
    for (final ScaleDeviceOption item in items) {
      if (_matchesCanonical(item, canonical)) {
        if (item.isArchived) {
          final int index = items.indexOf(item);
          final ScaleDeviceOption restored = item.copyWith(
            name: clean,
            isArchived: false,
            updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          );
          items[index] = restored;
          await _save(_normalizeDefaults(items));
          return restored;
        }
        return item;
      }
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ScaleDeviceOption created = ScaleDeviceOption(
      id: _uuid.v4(),
      name: clean,
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
      isDefault: makeDefault || items.where((item) => !item.isArchived).isEmpty,
    );
    if (created.isDefault) {
      for (int index = 0; index < items.length; index += 1) {
        items[index] = items[index].copyWith(isDefault: false);
      }
    }
    items.add(created);
    await _save(_normalizeDefaults(items));
    return created;
  }

  Future<void> rename(String id, String name) async {
    await ensureMigrated();
    final String clean = _cleanName(name);
    if (clean.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Il nome del dispositivo è vuoto.');
    }
    final List<ScaleDeviceOption> items = loadAll().toList();
    final int index =
        items.indexWhere((ScaleDeviceOption item) => item.id == id);
    if (index < 0) {
      throw StateError('Dispositivo non trovato.');
    }
    final String canonical = _canonical(clean);
    ScaleDeviceOption? collision;
    for (final ScaleDeviceOption item in items) {
      if (item.id != id && _matchesCanonical(item, canonical)) {
        collision = item;
        break;
      }
    }
    if (collision != null) {
      throw StateError(
        'Nome già associato al dispositivo "${collision.name}". Usa la fusione.',
      );
    }
    final ScaleDeviceOption current = items[index];
    final List<String> aliases = <String>{...current.aliases, current.name}
        .where((value) => _canonical(value) != canonical)
        .toList(growable: false);
    items[index] = current.copyWith(
      name: clean,
      aliases: aliases,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _save(items);
  }

  /// Compatibility method: removing now archives the identity and keeps a tombstone.
  Future<void> remove(String id) async {
    await archive(id);
  }

  Future<void> archive(String id) async {
    await ensureMigrated();
    final List<ScaleDeviceOption> items = loadAll().toList();
    final int index =
        items.indexWhere((ScaleDeviceOption item) => item.id == id);
    if (index < 0) {
      throw StateError('Dispositivo non trovato.');
    }
    items[index] = items[index].copyWith(
      isArchived: true,
      isDefault: false,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _save(_normalizeDefaults(items));
  }

  Future<void> makeDefault(String id) async {
    await ensureMigrated();
    final List<ScaleDeviceOption> items = loadAll()
        .map(
          (ScaleDeviceOption item) => item.copyWith(
            isDefault: !item.isArchived && item.id == id,
            updatedAtEpochMs: item.id == id
                ? DateTime.now().millisecondsSinceEpoch
                : item.updatedAtEpochMs,
          ),
        )
        .toList(growable: false);
    if (!items.any((ScaleDeviceOption item) => item.isDefault)) {
      throw StateError('Dispositivo non trovato o archiviato.');
    }
    await _save(items);
  }

  Future<ScaleDeviceOption> merge({
    required String sourceId,
    required String targetId,
  }) async {
    if (sourceId == targetId) {
      throw ArgumentError('Sorgente e destinazione coincidono.');
    }
    await ensureMigrated();
    final List<ScaleDeviceOption> items = loadAll().toList();
    final int sourceIndex = items.indexWhere((item) => item.id == sourceId);
    final int targetIndex = items.indexWhere((item) => item.id == targetId);
    if (sourceIndex < 0 || targetIndex < 0) {
      throw StateError('Dispositivo sorgente o destinazione non trovato.');
    }
    final ScaleDeviceOption source = items[sourceIndex];
    final ScaleDeviceOption target = items[targetIndex];
    final List<String> aliases = <String>{
      ...target.aliases,
      target.name,
      ...source.aliases,
      source.name,
    }.where((value) => _canonical(value) != _canonical(target.name)).toList();
    final ScaleDeviceOption merged = target.copyWith(
      aliases: aliases,
      isDefault: target.isDefault || source.isDefault,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    items[targetIndex] = merged;
    items[sourceIndex] = source.copyWith(
      isArchived: true,
      isDefault: false,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _save(_normalizeDefaults(items));
    return merged;
  }

  ScaleDeviceOption? findByStoredValue(String value) {
    final String id = tokenId(value);
    if (id.isNotEmpty) {
      for (final ScaleDeviceOption item in loadAll()) {
        if (item.id == id) {
          return item;
        }
      }
    }
    final String canonical = _canonical(displayName(value));
    for (final ScaleDeviceOption item in loadAll()) {
      if (_matchesCanonical(item, canonical)) {
        return item;
      }
    }
    return null;
  }

  ScaleDeviceOption? defaultDevice() {
    final List<ScaleDeviceOption> items = load();
    for (final ScaleDeviceOption item in items) {
      if (item.isDefault) {
        return item;
      }
    }
    return items.isEmpty ? null : items.first;
  }

  Map<String, Object?> exportPortable() {
    final List<ScaleDeviceOption> all = loadAll();
    return <String, Object?>{
      'schemaVersion': 1,
      'defaultDeviceId': defaultDevice()?.id,
      'devices': all.map((item) => item.toJson()).toList(growable: false),
      'tombstones': all
          .where((item) => item.isArchived)
          .map((item) => item.id)
          .toList(growable: false),
    };
  }

  Future<void> importPortable(Map<String, Object?> payload) async {
    final Object? rawDevices = payload['devices'];
    if (rawDevices is! List) {
      throw const FormatException('Catalogo dispositivi non valido.');
    }
    final List<ScaleDeviceOption> devices = rawDevices
        .whereType<Map>()
        .map(
          (Map item) => ScaleDeviceOption.fromJson(
            item.map(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .where(
            (item) => item.id.trim().isNotEmpty && item.name.trim().isNotEmpty)
        .toList(growable: false);
    await _save(_normalizeDefaults(devices));
  }

  static String encode(ScaleDeviceOption device) {
    final String name = base64Url.encode(utf8.encode(device.name));
    return '$tokenPrefix${device.id}::$name';
  }

  static String tokenId(String value) {
    final String clean = value.trim();
    if (!clean.startsWith(tokenPrefix)) {
      return '';
    }
    final int separator = clean.indexOf('::');
    return separator > tokenPrefix.length
        ? clean.substring(tokenPrefix.length, separator)
        : clean.substring(tokenPrefix.length);
  }

  static String displayName(String value) {
    final String clean = value.trim();
    if (!clean.startsWith(tokenPrefix)) {
      return clean;
    }
    final int separator = clean.indexOf('::');
    if (separator < 0 || separator + 2 >= clean.length) {
      return clean;
    }
    try {
      return utf8.decode(base64Url.decode(clean.substring(separator + 2)));
    } on FormatException {
      return clean;
    }
  }

  List<ScaleDeviceOption> _decodeV2(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const <ScaleDeviceOption>[];
      }
      final Object? rawDevices = decoded['devices'];
      if (rawDevices is! List) {
        return const <ScaleDeviceOption>[];
      }
      return _normalizeDefaults(
        rawDevices
            .whereType<Map>()
            .map(
              (Map item) => ScaleDeviceOption.fromJson(
                item.map(
                  (Object? key, Object? value) =>
                      MapEntry(key.toString(), value),
                ),
              ),
            )
            .where(
              (item) =>
                  item.id.trim().isNotEmpty && item.name.trim().isNotEmpty,
            )
            .toList(growable: false),
      );
    } on FormatException {
      return const <ScaleDeviceOption>[];
    }
  }

  List<ScaleDeviceOption> _decodeLegacy(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ScaleDeviceOption>[];
      }
      return decoded
          .whereType<Map>()
          .map((Map item) {
            final Map<String, Object?> json = item.map(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            );
            final int created =
                int.tryParse((json['createdAtEpochMs'] ?? '0').toString()) ?? 0;
            return ScaleDeviceOption(
              id: (json['id'] ?? '').toString(),
              name: (json['name'] ?? '').toString(),
              createdAtEpochMs: created,
              updatedAtEpochMs: created,
              isDefault: json['isDefault'] == true,
            );
          })
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
    } on FormatException {
      return const <ScaleDeviceOption>[];
    }
  }

  Future<void> _save(List<ScaleDeviceOption> items) async {
    final Map<String, Object?> root = <String, Object?>{
      'schemaVersion': schemaVersion,
      'defaultDeviceId': items.where((item) => item.isDefault).firstOrNull?.id,
      'devices': items.map((item) => item.toJson()).toList(growable: false),
      'tombstones': items
          .where((item) => item.isArchived)
          .map((item) => item.id)
          .toList(growable: false),
    };
    await _preferences.setString(storageKey, jsonEncode(root));
  }

  static List<ScaleDeviceOption> _normalizeDefaults(
    List<ScaleDeviceOption> source,
  ) {
    if (source.isEmpty) {
      return const <ScaleDeviceOption>[];
    }
    bool seenDefault = false;
    final List<ScaleDeviceOption> result = <ScaleDeviceOption>[];
    for (final ScaleDeviceOption item in source) {
      final bool selected = !item.isArchived && item.isDefault && !seenDefault;
      seenDefault = seenDefault || selected;
      result.add(item.copyWith(isDefault: selected));
    }
    if (!seenDefault) {
      final int firstActive = result.indexWhere((item) => !item.isArchived);
      if (firstActive >= 0) {
        result[firstActive] = result[firstActive].copyWith(isDefault: true);
      }
    }
    return List<ScaleDeviceOption>.unmodifiable(result);
  }

  static bool _matchesCanonical(ScaleDeviceOption item, String canonical) {
    if (_canonical(item.name) == canonical) {
      return true;
    }
    return item.aliases.any((alias) => _canonical(alias) == canonical);
  }

  static String _canonical(String input) {
    return CompositionReliabilityCalculator.canonicalDeviceCode(input);
  }

  static String _cleanName(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
