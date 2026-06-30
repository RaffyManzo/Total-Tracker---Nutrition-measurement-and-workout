import 'package:yaml/yaml.dart';

class ObsidianFrontmatterParseResult {
  const ObsidianFrontmatterParseResult({
    required this.data,
    required this.warnings,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> warnings;

  bool get hasFrontmatter => data.isNotEmpty;
}

class ObsidianFrontmatterParser {
  const ObsidianFrontmatterParser();

  ObsidianFrontmatterParseResult parse(
    String markdown, {
    required String relativePath,
  }) {
    final List<Map<String, dynamic>> warnings = <Map<String, dynamic>>[];
    final List<String> lines = markdown.replaceAll('\r\n', '\n').split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      warnings.add(_warning(relativePath, 'missing_frontmatter'));
      return ObsidianFrontmatterParseResult(
        data: <String, dynamic>{},
        warnings: warnings,
      );
    }

    int? endLine;
    for (int index = 1; index < lines.length; index += 1) {
      if (lines[index].trim() == '---') {
        endLine = index;
        break;
      }
    }
    if (endLine == null) {
      warnings.add(_warning(relativePath, 'unterminated_frontmatter'));
      return ObsidianFrontmatterParseResult(
        data: <String, dynamic>{},
        warnings: warnings,
      );
    }

    final String yamlText = lines.sublist(1, endLine).join('\n');
    try {
      final dynamic loaded = loadYaml(yamlText);
      final dynamic normalized = _normalizeYaml(loaded);
      if (normalized is Map<String, dynamic>) {
        return ObsidianFrontmatterParseResult(
          data: normalized,
          warnings: warnings,
        );
      }
      warnings.add(_warning(relativePath, 'frontmatter_not_map'));
    } catch (error) {
      warnings.add(
        _warning(relativePath, 'yaml_parse_error', message: error.toString()),
      );
    }

    return ObsidianFrontmatterParseResult(
      data: <String, dynamic>{},
      warnings: warnings,
    );
  }

  dynamic _normalizeYaml(dynamic value) {
    if (value is YamlMap) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): _normalizeYaml(entry.value),
      };
    }
    if (value is YamlList) {
      return <dynamic>[
        for (final dynamic item in value) _normalizeYaml(item),
      ];
    }
    return value;
  }

  Map<String, dynamic> _warning(
    String relativePath,
    String code, {
    String? message,
  }) {
    return <String, dynamic>{
      'relativePath': relativePath,
      'code': code,
      if (message != null) 'message': message,
    };
  }
}
