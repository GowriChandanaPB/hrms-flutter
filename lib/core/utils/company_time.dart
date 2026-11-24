import '../config/app_config.dart';

DateTime companyWallTime(DateTime instant) {
  if (AppConfig.timezone != 'Asia/Kolkata') {
    throw UnsupportedError(
      'Unsupported company timezone: ${AppConfig.timezone}',
    );
  }

  final shifted = instant.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

DateTime companyCalendarDate(DateTime instant) {
  final wallTime = companyWallTime(instant);
  return DateTime(wallTime.year, wallTime.month, wallTime.day);
}

bool isSameCompanyDay(DateTime first, DateTime second) =>
    companyCalendarDate(first) == companyCalendarDate(second);
