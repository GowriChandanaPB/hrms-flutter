
enum AttendanceEventType { checkIn, checkOut }

enum AttendanceSyncStatus { pending, synced, rejected }

class AttendanceEventModel {
  final String id;
  final String employeeId;
  final AttendanceEventType type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final AttendanceSyncStatus syncStatus;

  const AttendanceEventModel({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.syncStatus = AttendanceSyncStatus.pending,
  });

  factory AttendanceEventModel.fromJson(Map<String, dynamic> json) {
    final eventType = switch (json['type']) {
      'check_in' => AttendanceEventType.checkIn,
      'check_out' => AttendanceEventType.checkOut,
      _ => throw FormatException(
          'Invalid attendance event type: ${json['type']}',
        ),
    };

    final latitude = json['latitude'];
    final longitude = json['longitude'];

    if (latitude is! num || longitude is! num) {
      throw const FormatException(
        'Attendance coordinates must be numeric.',
      );
    }

    return AttendanceEventModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      type: eventType,
      timestamp: DateTime.parse(json['timestamp'].toString()),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      syncStatus: AttendanceSyncStatus.values.firstWhere(
        (status) => status.name == json['syncStatus'],
        orElse: () => AttendanceSyncStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'type': type == AttendanceEventType.checkIn
            ? 'check_in'
            : 'check_out',
        'timestamp': timestamp.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'syncStatus': syncStatus.name,
      };
}
