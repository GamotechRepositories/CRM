/// Indian Standard Time (UTC+05:30) helpers for display.
class IstTime {
  IstTime._();

  static const offset = Duration(hours: 5, minutes: 30);

  /// Parse API datetime and convert to IST wall-clock.
  static DateTime? parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return toIst(value);
    var raw = value.toString().trim();
    if (raw.isEmpty) return null;

    // Mongo/API often sends ISO without Z — treat naive timestamps as UTC.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(raw) &&
        !raw.endsWith('Z') &&
        !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw)) {
      raw = '${raw}Z';
    }

    final d = DateTime.tryParse(raw);
    if (d == null) return null;
    return toIst(d);
  }

  /// Convert any DateTime to IST (same instant, IST offset as local fields).
  static DateTime toIst(DateTime d) {
    final utc = d.isUtc ? d : d.toUtc();
    return utc.add(offset);
  }

  /// Current IST wall-clock.
  static DateTime now() => toIst(DateTime.now().toUtc());

  /// `HH:mm` in IST (24-hour).
  static String formatHm(dynamic value) {
    final d = parse(value);
    if (d == null) return '—';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// `h:mm:ss AM/PM` in IST.
  static String formatTimeOfDay(dynamic value) {
    final d = parse(value);
    if (d == null) return '—';
    final hour12 = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$hour12:$m:$s $ampm';
  }

  /// `HH:mm` only (no seconds) 12-hour.
  static String formatTimeShort(dynamic value) {
    final d = parse(value);
    if (d == null) return '—';
    final hour12 = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final m = d.minute.toString().padLeft(2, '0');
    return '$hour12:$m $ampm';
  }

  /// YYYY-MM-DD in IST.
  static String dateKey([DateTime? ref]) {
    final d = ref != null ? toIst(ref.toUtc()) : now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
