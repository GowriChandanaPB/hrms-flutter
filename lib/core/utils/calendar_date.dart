DateTime calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String calendarDateString(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime parseCalendarDate(Object? value) {
  final parsed = DateTime.parse(value.toString());
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int inclusiveCalendarDays(DateTime start, DateTime end) {
  final utcStart = DateTime.utc(start.year, start.month, start.day);
  final utcEnd = DateTime.utc(end.year, end.month, end.day);
  return utcEnd.difference(utcStart).inDays + 1;
}