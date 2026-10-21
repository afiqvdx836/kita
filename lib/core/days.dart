/// Whole calendar days from [since] to [today], ignoring time of day and DST.
int daysTogether(DateTime since, DateTime today) {
  final a = DateTime.utc(since.year, since.month, since.day);
  final b = DateTime.utc(today.year, today.month, today.day);
  return b.difference(a).inDays;
}

/// The next round milestone after [days]: every 100 days, plus each full year.
({int day, int inDays}) nextMilestone(DateTime since, DateTime today) {
  final days = daysTogether(since, today);
  final next100 = (days ~/ 100 + 1) * 100;

  var years = today.year - since.year;
  var anniversary = DateTime(since.year + years, since.month, since.day);
  if (daysTogether(anniversary, today) >= 0) {
    years += 1;
    anniversary = DateTime(since.year + years, since.month, since.day);
  }
  final anniversaryDay = daysTogether(since, anniversary);

  final day = anniversaryDay < next100 ? anniversaryDay : next100;
  return (day: day, inDays: day - days);
}

/// Parses a Postgres `date` string (YYYY-MM-DD) as a local calendar date.
DateTime? parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final d = DateTime.parse(value);
  return DateTime(d.year, d.month, d.day);
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
