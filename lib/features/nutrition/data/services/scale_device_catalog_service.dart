import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/composition_reliability.dart';

class ScaleDeviceOption {
  const ScaleDeviceOption({
    required this.id,
    required this.name,
    required this.createdAtEpochMs,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final int createdAtEpochMs;
  final bool isDefault;

  ScaleDeviceOption copyWith({String? name, bool? isDefault}) {
    return ScaleDeviceOption(
      id: id,
      name: name ?? this.name,
      createdAtEpochMs: createdAtEpochMs,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'id': id,
        'name': name,
        'createdAtEpochMs': createdAtEpochMs,
        'isDefault': isDefault,
      };

  static ScaleDeviceOption fromJson(Map<String, Object?> json) {
    return ScaleDeviceOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      createdAtEpochMs:
          int.tryParse((json['createdAtEpochMs'] ?? '0').toString()) ?? 0,
      isDefault: json['isDefault'] == true,
    );
  }
}

class ScaleDeviceCatalogService {
  ScaleDeviceCatalogService(this._preferences, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const String storageKey = 'scale_device_catalog_v1';
  static const String tokenPrefix = 'ttdev:';

  final SharedPreferences _preferences;
  final Uuid _uuid;

  List<ScaleDeviceOption> load() {
    final String? raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ScaleDeviceOption>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return const <ScaleDeviceOption>[];
      }
      final List<ScaleDeviceOption> items = decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) => ScaleDeviceOption.fromJson(
              item.map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>(key.toString(), value),
              ),
            ),
          )
          .where(
            (ScaleDeviceOption item) =>
                item.id.trim().isNotEmpty && item.name.trim().isNotEmpty,
          )
          .toList(growable: false);
      return _normalizeDefaults(items);
    } on FormatException {
      return const <ScaleDeviceOption>[];
    }
  }

  Future<void> mergeStoredValues(Iterable<String> values) async {
    final List<ScaleDeviceOption> items = load().toList();
    final Set<String> knownIds =
        items.map((ScaleDeviceOption item) => item.id).toSet();
    final Set<String> knownCanonicalNames = items
        .map(
          (ScaleDeviceOption item) =>
              CompositionReliabilityCalculator.canonicalDeviceCode(item.name),
        )
        .toSet();
    bool changed = false;
    for (final String value in values) {
      final String name = displayName(value).trim();
      final String canonicalName =
          CompositionReliabilityCalculator.canonicalDeviceCode(name);
      if (name.isEmpty ||
          canonicalName == 'unspecified' ||
          canonicalName == 'mixed') {
        continue;
      }
      String id = tokenId(value);
      if (id.isEmpty) id = _uuid.v4();
      if (knownIds.contains(id) ||
          knownCanonicalNames.contains(canonicalName)) {
        continue;
      }
      items.add(
        ScaleDeviceOption(
          id: id,
          name: name,
          createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          isDefault: items.isEmpty,
        ),
      );
      knownIds.add(id);
      knownCanonicalNames.add(canonicalName);
      changed = true;
    }
    if (changed) await _save(_normalizeDefaults(items));
  }

  Future<ScaleDeviceOption> add(String name, {bool makeDefault = false}) async {
    final String clean = _cleanName(name);
    if (clean.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Il nome del dispositivo è vuoto.');
    }
    final List<ScaleDeviceOption> items = load().toList();
    final String canonical =
        CompositionReliabilityCalculator.canonicalDeviceCode(clean);
    for (final ScaleDeviceOption item in items) {
      if (CompositionReliabilityCalculator.canonicalDeviceCode(item.name) ==
          canonical) {
        return item;
      }
    }
    final ScaleDeviceOption created = ScaleDeviceOption(
      id: _uuid.v4(),
      name: clean,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      isDefault: makeDefault || items.isEmpty,
    );
    if (created.isDefault) {
      for (int index = 0; index < items.length; index += 1) {
        items[index] = items[index].copyWith(isDefault: false);
      }
    }
    items.add(created);
    await _save(items);
    return created;
  }

  Future<void> rename(String id, String name) async {
    final String clean = _cleanName(name);
    if (clean.isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Il nome del dispositivo è vuoto.');
    }
    final List<ScaleDeviceOption> items = load().toList();
    final int index =
        items.indexWhere((ScaleDeviceOption item) => item.id == id);
    if (index < 0) {
      throw StateError('Dispositivo non trovato.');
    }
    items[index] = items[index].copyWith(name: clean);
    await _save(items);
  }

  Future<void> remove(String id) async {
    final List<ScaleDeviceOption> items = load().toList()
      ..removeWhere((ScaleDeviceOption item) => item.id == id);
    await _save(_normalizeDefaults(items));
  }

  Future<void> makeDefault(String id) async {
    final List<ScaleDeviceOption> items = load()
        .map(
          (ScaleDeviceOption item) => item.copyWith(isDefault: item.id == id),
        )
        .toList(growable: false);
    if (!items.any((ScaleDeviceOption item) => item.isDefault)) {
      throw StateError('Dispositivo non trovato.');
    }
    await _save(items);
  }

  ScaleDeviceOption? findByStoredValue(String value) {
    final String id = tokenId(value);
    if (id.isNotEmpty) {
      for (final ScaleDeviceOption item in load()) {
        if (item.id == id) return item;
      }
    }
    final String canonical =
        CompositionReliabilityCalculator.canonicalDeviceCode(value);
    for (final ScaleDeviceOption item in load()) {
      if (CompositionReliabilityCalculator.canonicalDeviceCode(item.name) ==
          canonical) {
        return item;
      }
    }
    return null;
  }

  ScaleDeviceOption? defaultDevice() {
    final List<ScaleDeviceOption> items = load();
    for (final ScaleDeviceOption item in items) {
      if (item.isDefault) return item;
    }
    return items.isEmpty ? null : items.first;
  }

  static String encode(ScaleDeviceOption device) {
    final String name = base64Url.encode(utf8.encode(device.name));
    return '$tokenPrefix${device.id}::$name';
  }

  static String tokenId(String value) {
    final String clean = value.trim();
    if (!clean.startsWith(tokenPrefix)) return '';
    final int separator = clean.indexOf('::');
    return separator > tokenPrefix.length
        ? clean.substring(tokenPrefix.length, separator)
        : clean.substring(tokenPrefix.length);
  }

  static String displayName(String value) {
    final String clean = value.trim();
    if (!clean.startsWith(tokenPrefix)) return clean;
    final int separator = clean.indexOf('::');
    if (separator < 0 || separator + 2 >= clean.length) return clean;
    try {
      return utf8.decode(base64Url.decode(clean.substring(separator + 2)));
    } on FormatException {
      return clean;
    }
  }

  Future<void> _save(List<ScaleDeviceOption> items) async {
    final String raw = jsonEncode(
      items.map((ScaleDeviceOption item) => item.toJson()).toList(),
    );
    await _preferences.setString(storageKey, raw);
  }

  static List<ScaleDeviceOption> _normalizeDefaults(
    List<ScaleDeviceOption> source,
  ) {
    if (source.isEmpty) return const <ScaleDeviceOption>[];
    bool seenDefault = false;
    final List<ScaleDeviceOption> result = <ScaleDeviceOption>[];
    for (final ScaleDeviceOption item in source) {
      final bool selected = item.isDefault && !seenDefault;
      seenDefault = seenDefault || selected;
      result.add(item.copyWith(isDefault: selected));
    }
    if (!seenDefault) {
      result[0] = result[0].copyWith(isDefault: true);
    }
    return List<ScaleDeviceOption>.unmodifiable(result);
  }

  static String _cleanName(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
