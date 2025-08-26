import 'package:reframe/model/account.dart';
import 'package:reframe/model/deposit_product.dart';

import 'common.dart';

class ProductApplication {
  final int id;
  final DepositProduct product;
  final Account productAccount;
  final ApplicationStatus? status;
  final DateTime? startAt;
  final DateTime? closeAt;

  // 금리/기간 스냅샷
  final double? baseRateAtEnroll; // 예: 3.200 (== 3.2%)
  final double? effectiveRateAnnual; // 현재 적용 연이율 (지금은 기본과 동일)
  final int? termMonthsAtEnroll;

  final int? walkThresholdSteps;

  ProductApplication({
    required this.id,
    required this.product,
    required this.productAccount,
    this.status,
    this.startAt,
    this.closeAt,
    this.baseRateAtEnroll,
    this.effectiveRateAnnual,
    this.termMonthsAtEnroll,
    this.walkThresholdSteps,
  });

  factory ProductApplication.fromJson(Map<String, dynamic> json) {
    return ProductApplication(
      id: json['id'] as int,
      product: DepositProduct.fromJson(json['product']),
      productAccount: Account.fromJson(json['productAccount']),
      status: applicationStatus(json['status']),
      startAt: parseDate(json['startAt']),
      closeAt: parseDate(json['closeAt']),
      baseRateAtEnroll: parseDouble(json['baseRateAtEnroll']),
      effectiveRateAnnual: parseDouble(json['effectiveRateAnnual']),
      termMonthsAtEnroll: parseInt(json['termMonthsAtEnroll']),
      walkThresholdSteps: json['walkThresholdSteps'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {

    'id': id,
    'product': product,
    'status': status?.name.toUpperCase(),
    'startAt': startAt?.toIso8601String(),
    'closeAt': closeAt?.toIso8601String(),
    'baseRateAtEnroll': baseRateAtEnroll,
    'effectiveRateAnnual': effectiveRateAnnual,
    'termMonthsAtEnroll': termMonthsAtEnroll,
    'walkThresholdSteps': walkThresholdSteps,
  };

}
