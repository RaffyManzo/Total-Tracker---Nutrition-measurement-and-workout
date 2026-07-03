import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/open_nutrition_import_service.dart';

void main() {
  test('OpenNutrition archive limits are ordered and non-zero', () {
    expect(OpenNutritionDatasetConstants.maximumArchiveBytes, greaterThan(0));
    expect(
      OpenNutritionDatasetConstants.maximumExtractedBytes,
      greaterThan(OpenNutritionDatasetConstants.maximumArchiveBytes),
    );
  });
}
