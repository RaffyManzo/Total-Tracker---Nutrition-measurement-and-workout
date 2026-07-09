import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/diagnostics/diagnostic_privacy.dart';

void main() {
  test('redacts personal, body, workout and path values', () {
    final Map<String, Object?> safe = DiagnosticPrivacy.sanitizeData(
      <String, Object?>{
        'eventId': 'evt-1',
        'reasonCode': 'resume_coalesced',
        'unclassifiedDetail': 'private ingredient: banana',
        'packageVersion': 1,
        'preparationMs': 22,
        'averageMs': 33,
        'personName': 'Mario Rossi',
        'notes': 'private note',
        'message': 'private ingredient name',
        'title': 'private meal title',
        'weightKg': 64.2,
        'currentCalories': 1800,
        'steps': 9000,
        'information': <String>['private widget text'],
        'workoutLoad': 90,
        'reps': 10,
        'query': 'private search',
        'filePath': r'C:\Users\name\private\file.txt',
        'stack': r'failure at C:\Users\name\project\file.dart:4',
      },
    );

    expect(safe['eventId'], 'evt-1');
    expect(safe['reasonCode'], 'resume_coalesced');
    expect(safe['unclassifiedDetail'], '<redacted-text>');
    expect(safe['packageVersion'], 1);
    expect(safe['preparationMs'], 22);
    expect(safe['averageMs'], 33);
    expect(safe['personName'], '<redacted>');
    expect(safe['notes'], '<redacted>');
    expect(safe['message'], '<redacted>');
    expect(safe['title'], '<redacted>');
    expect(safe['weightKg'], '<redacted>');
    expect(safe['currentCalories'], '<redacted>');
    expect(safe['steps'], '<redacted>');
    expect(safe['information'], '<redacted>');
    expect(safe['workoutLoad'], '<redacted>');
    expect(safe['reps'], '<redacted>');
    expect(safe['query'], '<redacted>');
    expect(safe['filePath'], '<redacted-path>');
    expect(safe['stack'], isNot(contains(r'C:\Users')));
  });

  test('exception details are reduced to the runtime type', () {
    final String safe = DiagnosticPrivacy.sanitizeError(
      StateError('private ingredient: banana'),
    );

    expect(safe, contains('StateError'));
    expect(safe, isNot(contains('banana')));
    expect(safe, isNot(contains('private ingredient')));
  });
}
