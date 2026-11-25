class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  static const String employeeId = String.fromEnvironment(
    'EMPLOYEE_ID',
    defaultValue: 'REBS-1024',
  );

  static const double officeLatitude = 10.027786;
  static const double officeLongitude = 76.336622;
  static const double allowedOfficeRadiusMetres = 200.0;
  static const double maximumLocationAccuracyMetres = 100.0;
  static const String timezone = 'Asia/Kolkata';
}
