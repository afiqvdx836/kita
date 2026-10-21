import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/days.dart';
import 'package:kita/data/models.dart';

void main() {
  group('daysTogether', () {
    test('same day is 0', () {
      expect(daysTogether(DateTime(2024, 2, 14), DateTime(2024, 2, 14, 23, 59)), 0);
    });

    test('ignores time of day', () {
      expect(daysTogether(DateTime(2024, 2, 14, 22), DateTime(2024, 2, 15, 1)), 1);
    });

    test('counts across a leap year', () {
      expect(daysTogether(DateTime(2024, 2, 14), DateTime(2025, 2, 14)), 366);
    });
  });

  group('nextMilestone', () {
    test('picks the next 100 when it comes before the anniversary', () {
      final m = nextMilestone(DateTime(2024, 1, 1), DateTime(2024, 3, 1)); // day 60
      expect(m, (day: 100, inDays: 40));
    });

    test('picks the anniversary when it comes first', () {
      final m = nextMilestone(DateTime(2024, 1, 1), DateTime(2024, 12, 20)); // day 354
      expect(m, (day: 366, inDays: 12));
    });

    test('on the anniversary itself, looks to what comes next', () {
      final m = nextMilestone(DateTime(2023, 6, 1), DateTime(2024, 6, 1)); // day 366
      expect(m, (day: 400, inDays: 34));
    });
  });

  test('parseDate and formatDate round-trip a Postgres date', () {
    final d = parseDate('2024-02-14')!;
    expect(d, DateTime(2024, 2, 14));
    expect(formatDate(d), '2024-02-14');
    expect(parseDate(null), isNull);
  });

  test('Task.fromMap reads a Supabase row', () {
    final t = Task.fromMap({
      'id': 't1',
      'title': 'Beli barang dapur',
      'done': true,
      'done_by': 'u2',
      'created_by': 'u1',
      'created_at': '2026-10-21T04:00:00+00:00',
      'due_date': null,
    });
    expect(t.title, 'Beli barang dapur');
    expect(t.done, isTrue);
    expect(t.doneBy, 'u2');
    expect(t.dueDate, isNull);
  });
}
