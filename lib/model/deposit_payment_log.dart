import 'common.dart';

class DepositPaymentLog {
  final int round; // 회차(월/일차)
  final int amount; // 납입 금액
  final DateTime? paidAt; // 실제 납입시각 또는 예정일자(UNPAID)
  final PaymentStatus? status; // UNPAID | PAID

  final int? walkStepsTotal;        // NUMBER(19,0)
  final int? walkLastSyncSteps;     // NUMBER(19,0)
  final double? walkBonusApplied;   // NUMBER(5,2)  (보너스율 혹은 가점)
  final bool? walkConfirmed;        // VARCHAR2(1) 'Y'/'N'

  DepositPaymentLog({
    required this.round,
    required this.amount,
    this.paidAt,
    this.status,
    this.walkStepsTotal,
    this.walkLastSyncSteps,
    this.walkBonusApplied,
    this.walkConfirmed,
  });

  factory DepositPaymentLog.fromJson(Map<String, dynamic> json) {
    String? yn(dynamic v) => v?.toString();
    bool? asBoolYN(dynamic v) {
      final s = yn(v);
      if (s == null) return null;
      return s.toUpperCase() == 'Y';
    }

    int? asInt(dynamic v) =>
        v == null ? null : int.tryParse(v.toString());
    double? asDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());

    return DepositPaymentLog(
      round: parseInt(json['round']) ?? 0,
      amount: parseInt(json['amount']) ?? 0,
      paidAt: parseDate(json['paidAt']),
      status: paymentStatus(json['status']),
      walkStepsTotal: asInt(json['walkStepsTotal'] ?? json['walk_steps_total']),
      walkLastSyncSteps: asInt(json['walkLastSyncSteps'] ?? json['walk_last_sync_steps']),
      walkBonusApplied: asDouble(json['walkBonusApplied'] ?? json['walk_bonus_applied']),
      walkConfirmed: asBoolYN(json['walkConfirmedYn'] ?? json['walk_confirmed_yn']),
    );
  }

  Map<String, dynamic> toJson() => {

    'round': round,
    'amount': amount,
    'paidAt': paidAt?.toIso8601String(),
    'status': status?.name.toUpperCase(),
    'walkStepsTotal': walkStepsTotal,
    'walkLastSyncSteps': walkLastSyncSteps,
    'walkBonusApplied': walkBonusApplied,
    'walkConfirmedYn': walkConfirmed == null ? null : (walkConfirmed! ? 'Y' : 'N'),
  };

}
