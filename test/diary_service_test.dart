import 'package:fjellfisk/services/diary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiaryService date ranges', () {
    test('day range uses local calendar boundaries', () {
      final range = DiaryService.rangeFor(
        DiaryPeriod.day,
        DateTime(2026, 10, 25, 22, 30),
      );

      expect(range.start, DateTime(2026, 10, 25));
      expect(range.endExclusive, DateTime(2026, 10, 26));
    });

    test('month range crosses year boundary', () {
      final range = DiaryService.rangeFor(
        DiaryPeriod.month,
        DateTime(2026, 12, 20),
      );

      expect(range.start, DateTime(2026, 12));
      expect(range.endExclusive, DateTime(2027));
    });

    test('year range covers one calendar year', () {
      final range = DiaryService.rangeFor(
        DiaryPeriod.year,
        DateTime(2026, 6, 15),
      );

      expect(range.start, DateTime(2026));
      expect(range.endExclusive, DateTime(2027));
    });

    test('month navigation moves to first day in target month', () {
      final result = DiaryService.shiftFocus(
        DiaryPeriod.month,
        DateTime(2026, 1, 31),
        1,
      );

      expect(result, DateTime(2026, 2));
    });
  });
}
