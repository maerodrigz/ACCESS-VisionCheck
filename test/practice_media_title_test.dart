import 'package:access_mobile/shared/utils/practice_media_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validatePracticeMediaTitle', () {
    test('rejects empty', () {
      expect(validatePracticeMediaTitle('', isVideo: false), isNotNull);
      expect(validatePracticeMediaTitle('   ', isVideo: true), isNotNull);
    });

    test('accepts trimmed title within limit', () {
      expect(validatePracticeMediaTitle('  Sunset at the Beach  ', isVideo: false), isNull);
    });

    test('rejects over 80 characters', () {
      expect(validatePracticeMediaTitle('a' * 81, isVideo: false), isNotNull);
    });
  });

  group('practiceMediaDisplayTitle', () {
    test('fallback for empty and generic', () {
      expect(practiceMediaDisplayTitle(null, isVideo: false), 'Untitled Photo');
      expect(practiceMediaDisplayTitle('Practice Upload', isVideo: true), 'Untitled Video');
      expect(practiceMediaDisplayTitle('upload', mediaType: 'photo'), 'Untitled Photo');
    });

    test('preserves custom title', () {
      expect(
        practiceMediaDisplayTitle('School Event Highlights', mediaType: 'video'),
        'School Event Highlights',
      );
    });
  });

  group('normalizePracticeMediaTitle', () {
    test('trims whitespace', () {
      expect(normalizePracticeMediaTitle('  Hello  '), 'Hello');
    });
  });
}
