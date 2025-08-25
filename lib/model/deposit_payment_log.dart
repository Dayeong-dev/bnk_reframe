import 'common.dart';

class DepositPaymentLog {
  final int round; // 회차(월/일차)
  final int amount; // 납입 금액
  final DateTime? paidAt; // 실제 납입시각 또는 예정일자(UNPAID)
  final PaymentStatus? status; // UNPAID | PAID

  DepositPaymentLog({
    required this.round,
    required this.amount,
    this.paidAt,
    this.status,
  });

  factory DepositPaymentLog.fromJson(Map<String, dynamic> json) {
    return DepositPaymentLog(
      round: parseInt(json['round']) ?? 0,
      amount: parseInt(json['amount']) ?? 0,
      paidAt: parseDate(json['paidAt']),
      status: paymentStatus(json['status']),
    );
  }

  Map<String, dynamic> toJson() => {
        'round': round,
        'amount': amount,
        'paidAt': paidAt?.toIso8601String(),
        'status': status?.name.toUpperCase(),
      };
}
