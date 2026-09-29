import 'package:centralized_app/services/work_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fmt(String raw) {
    final r = WorkReminderService.parseWorkingHours(raw);
    if (r == null) return 'null';
    String hm(({int hour, int minute}) t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${hm(r.start)}-${hm(r.end)}';
  }

  test('parses common working hour formats', () {
    expect(fmt('9 AM - 6 PM'), '09:00-18:00');
    expect(fmt('9:30am to 6:30pm'), '09:30-18:30');
    expect(fmt('09:00 - 18:00'), '09:00-18:00');
    expect(fmt('10 - 7'), '10:00-19:00');
    expect(fmt('9.30 AM - 6.30 PM'), '09:30-18:30');
    expect(fmt('12 PM - 9 PM'), '12:00-21:00');
    expect(fmt(''), 'null');
    expect(fmt('Flexible'), 'null');
  });
}
