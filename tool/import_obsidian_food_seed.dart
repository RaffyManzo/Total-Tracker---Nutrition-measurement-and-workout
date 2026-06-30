import 'dart:convert';
import 'dart:io';

import 'package:total_tracker/features/nutrition/data/import/obsidian_food_seed.dart';
import 'package:total_tracker/features/nutrition/data/import/obsidian_frontmatter_parser.dart';

Future<void> main(List<String> args) async {
  final Map<String, String> options = _parseArgs(args);
  final String? sourceRootArg = options['source-root'];
  final String from = options['from'] ?? '2026-06-22';
  final String to = options['to'] ?? '2026-06-30';
  final String outputPath =
      options['output'] ?? 'assets/dev_seed/obsidian_food_${from}_$to.json';

  if (sourceRootArg == null || sourceRootArg.trim().isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/import_obsidian_food_seed.dart '
      '--source-root <path> --from YYYY-MM-DD --to YYYY-MM-DD',
    );
    exitCode = 64;
    return;
  }

  final Directory sourceRoot = Directory(sourceRootArg);
  if (!sourceRoot.existsSync()) {
    stdout.writeln('SOURCE_PATH_NOT_FOUND');
    exitCode = 66;
    return;
  }

  final ObsidianFoodSeedMapper mapper = ObsidianFoodSeedMapper();
  if (mapper.parseDate(from) == null || mapper.parseDate(to) == null) {
    stderr.writeln('Invalid date range.');
    exitCode = 64;
    return;
  }

  final List<File> files = _sourceFiles(sourceRoot, from, to);
  final ObsidianFrontmatterParser parser = ObsidianFrontmatterParser();
  final List<Map<String, dynamic>> days = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> meals = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> mealItems = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> warnings = <Map<String, dynamic>>[];
  int skipped = 0;

  for (final File file in files) {
    final String relativePath = _relativePath(sourceRoot, file);
    final String markdown = file.readAsStringSync();
    final ObsidianFrontmatterParseResult parsed =
        parser.parse(markdown, relativePath: relativePath);
    warnings.addAll(parsed.warnings);
    if (!parsed.hasFrontmatter) {
      skipped += 1;
      continue;
    }

    if (_isDayPath(relativePath)) {
      final Map<String, dynamic> day =
          mapper.normalizeDay(parsed.data, relativePath: relativePath);
      if (mapper.isWithinInclusive(day['date'] as String, from, to)) {
        days.add(day);
      } else {
        skipped += 1;
      }
      continue;
    }

    if (_isMealPath(relativePath)) {
      final Map<String, dynamic> meal =
          mapper.normalizeMeal(parsed.data, relativePath: relativePath);
      final String date = meal['date'] as String;
      final String slot = meal['meal_type'] as String;
      if (!mapper.isWithinInclusive(date, from, to)) {
        skipped += 1;
        continue;
      }
      if (!ObsidianFoodSeedConstants.mealSlots.contains(slot)) {
        warnings.add(<String, dynamic>{
          'relativePath': relativePath,
          'code': 'unsupported_meal_slot',
          'slot': slot,
        });
      }
      meals.add(meal);
      mealItems.addAll(
        (meal['items'] as List<dynamic>).cast<Map<String, dynamic>>(),
      );
      continue;
    }
  }

  days.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    return (a['date'] as String).compareTo(b['date'] as String);
  });
  meals.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final int dateCompare =
        (a['date'] as String).compareTo(b['date'] as String);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return _slotIndex(a['meal_type'] as String)
        .compareTo(_slotIndex(b['meal_type'] as String));
  });

  final Map<String, List<Map<String, dynamic>>> mealsByDate =
      <String, List<Map<String, dynamic>>>{};
  for (final Map<String, dynamic> meal in meals) {
    final List<Map<String, dynamic>> mealsForDate = mealsByDate.putIfAbsent(
      meal['date'] as String,
      () => <Map<String, dynamic>>[],
    );
    mealsForDate.add(meal);
  }

  for (final String date in _dateKeys(from, to)) {
    final bool hasDay =
        days.any((Map<String, dynamic> day) => day['date'] == date);
    if (!hasDay) {
      warnings.add(<String, dynamic>{
        'date': date,
        'code': 'missing_day_file',
      });
    }

    final List<Map<String, dynamic>> dayMeals =
        mealsByDate[date] ?? const <Map<String, dynamic>>[];
    if (dayMeals.isEmpty) {
      warnings.add(
        <String, dynamic>{
          'date': date,
          'code': 'missing_meals_for_date',
        },
      );
    }
  }

  for (final Map<String, dynamic> day in days) {
    final String date = day['date'] as String;
    final double? cachedCalories = mapper.readDouble(day['calories_in_kcal']);
    if (cachedCalories == null) {
      continue;
    }
    final double computedCalories =
        (mealsByDate[date] ?? const <Map<String, dynamic>>[]).fold<double>(0,
            (double sum, Map<String, dynamic> meal) {
      final Map<String, dynamic> totals =
          meal['totals'] as Map<String, dynamic>;
      return sum + (mapper.readDouble(totals['kcal']) ?? 0);
    });
    if ((cachedCalories - computedCalories).abs() > 1) {
      warnings.add(<String, dynamic>{
        'date': date,
        'code': 'daily_calorie_cache_mismatch',
        'cachedKcal': cachedCalories,
        'computedMealKcal': double.parse(computedCalories.toStringAsFixed(2)),
      });
    }
  }

  final Set<String> importedIngredientKeys = <String>{};
  for (final Map<String, dynamic> item in mealItems) {
    if (item['kind'] == 'ingredient') {
      final String source = mapper.readString(item['source']);
      final String name = mapper.readString(item['item_name']);
      importedIngredientKeys.add(source.isEmpty ? name : source);
    }
  }

  final Map<String, dynamic> seed = <String, dynamic>{
    'schemaVersion': ObsidianFoodSeedConstants.schemaVersion,
    'dateFrom': from,
    'dateTo': to,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'sourceFilesRead':
        files.map((File file) => _relativePath(sourceRoot, file)).toList(),
    'days': days,
    'meals': meals
        .map((Map<String, dynamic> meal) => <String, dynamic>{
              ...meal,
              'items': null,
            }..remove('items'))
        .toList(),
    'mealItems': mealItems,
    'warnings': warnings,
    'counts': <String, dynamic>{
      'sourceFilesRead': files.length,
      'days': days.length,
      'meals': meals.length,
      'mealItems': mealItems.length,
      'ingredients': importedIngredientKeys.length,
      'skipped': skipped,
      'warnings': warnings.length,
    },
  };

  final File output = File(outputPath);
  output.parent.createSync(recursive: true);
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  output.writeAsStringSync('${encoder.convert(seed)}\n');

  stdout.writeln(
    jsonEncode(<String, dynamic>{
      'output': output.path,
      'counts': seed['counts'],
    }),
  );
}

Map<String, String> _parseArgs(List<String> args) {
  final Map<String, String> options = <String, String>{};
  for (int index = 0; index < args.length; index += 1) {
    final String arg = args[index];
    if (!arg.startsWith('--')) {
      continue;
    }
    final String key = arg.substring(2);
    if (index + 1 < args.length && !args[index + 1].startsWith('--')) {
      options[key] = args[index + 1];
      index += 1;
    } else {
      options[key] = 'true';
    }
  }
  return options;
}

List<File> _sourceFiles(Directory sourceRoot, String from, String to) {
  final List<File> files = <File>[];
  final Set<String> seen = <String>{};
  void addFile(File file) {
    final String fullPath = file.absolute.path;
    if (seen.add(fullPath)) {
      files.add(file);
    }
  }

  for (final String relativePath in <String>[
    'Food Plan hub.md',
    'measurements/Measurements Hub.md',
  ]) {
    final File file = File('${sourceRoot.path}${Platform.pathSeparator}'
        '${relativePath.replaceAll('/', Platform.pathSeparator)}');
    if (file.existsSync()) {
      addFile(file);
    }
  }

  final Directory daysDir =
      Directory('${sourceRoot.path}${Platform.pathSeparator}days');
  if (daysDir.existsSync()) {
    for (final FileSystemEntity entity in daysDir.listSync()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.md')) {
        continue;
      }
      final String stem = _stem(entity);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(stem) &&
          const ObsidianFoodSeedMapper().isWithinInclusive(stem, from, to)) {
        addFile(entity);
      }
    }
  }

  final Directory mealsDir =
      Directory('${sourceRoot.path}${Platform.pathSeparator}meals');
  if (mealsDir.existsSync()) {
    for (final FileSystemEntity entity in mealsDir.listSync()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.md')) {
        continue;
      }
      final RegExpMatch? match =
          RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(_stem(entity));
      if (match != null &&
          const ObsidianFoodSeedMapper()
              .isWithinInclusive(match.group(1)!, from, to)) {
        addFile(entity);
      }
    }
  }

  files.sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

String _relativePath(Directory sourceRoot, File file) {
  final String root = sourceRoot.absolute.path;
  String fullPath = file.absolute.path;
  if (fullPath.startsWith(root)) {
    fullPath = fullPath.substring(root.length);
  }
  return fullPath
      .replaceAll(RegExp(r'^[\\\/]+'), '')
      .replaceAll(Platform.pathSeparator, '/');
}

bool _isDayPath(String relativePath) {
  return relativePath.startsWith('days/') &&
      RegExp(r'\d{4}-\d{2}-\d{2}\.md$').hasMatch(relativePath);
}

bool _isMealPath(String relativePath) {
  return relativePath.startsWith('meals/') &&
      relativePath.toLowerCase().endsWith('.md');
}

String _stem(FileSystemEntity entity) {
  final String name = entity.uri.pathSegments.last;
  return name.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
}

int _slotIndex(String slot) {
  final int index = ObsidianFoodSeedConstants.mealSlots.indexOf(slot);
  return index == -1 ? 99 : index;
}

List<String> _dateKeys(String from, String to) {
  final ObsidianFoodSeedMapper mapper = ObsidianFoodSeedMapper();
  final DateTime start = mapper.parseDate(from)!;
  final DateTime end = mapper.parseDate(to)!;
  final List<String> values = <String>[];
  for (DateTime day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))) {
    values.add(day.toIso8601String().split('T').first);
  }
  return values;
}
