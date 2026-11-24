
class LeaveBalanceModel {
  final int casualLeave;
  final int sickLeave;

  const LeaveBalanceModel({
    required this.casualLeave,
    required this.sickLeave,
  });

  int get totalAvailable => casualLeave + sickLeave;

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      casualLeave: (json['casualLeave'] as num?)?.toInt() ?? 0,
      sickLeave: (json['sickLeave'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'casualLeave': casualLeave,
        'sickLeave': sickLeave,
      };
}
