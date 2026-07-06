import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/preferences/target_model_preferences.dart';

void main() {
  test('steps policy banner is visible until current version is dismissed', () {
    expect(StepsExclusionPolicy.shouldShow(null), isTrue);
    expect(StepsExclusionPolicy.shouldShow('steps-exclusion-policy-0'), isTrue);
    expect(
      StepsExclusionPolicy.shouldShow(StepsExclusionPolicy.currentVersion),
      isFalse,
    );
  });
}
