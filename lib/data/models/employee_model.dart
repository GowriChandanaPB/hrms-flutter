
class EmployeeModel {
  final String id;
  final String name;
  final String department;
  final String designation;
  final String email;

  const EmployeeModel({
    required this.id,
    required this.name,
    required this.department,
    required this.designation,
    required this.email,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'department': department,
        'designation': designation,
        'email': email,
      };
}
