import 'package:reframe/model/product_application.dart';

import 'deposit_payment_log.dart';
import 'account.dart';
import 'deposit_product_rate.dart';

class ProductAccountDetail {
  final Account? account;
  final ProductApplication application;
  final List<DepositPaymentLog> depositPaymentLogList;
  final List<DepositProductRate> productRateList;

  final int? projectedInterestNow;
  final int? maturityAmountProjected;

  ProductAccountDetail({
    required this.account,
    required this.application,
    required this.depositPaymentLogList,
    required this.productRateList,
    this.projectedInterestNow,
    this.maturityAmountProjected,
  });

  factory ProductAccountDetail.fromJson(Map<String, dynamic> json) {
    return ProductAccountDetail(
      account: json['accountDTO'] == null
          ? null
          : Account.fromJson(json['accountDTO'] as Map<String, dynamic>),
      application: ProductApplication.fromJson(
          json['applicationDTO'] as Map<String, dynamic>),
      depositPaymentLogList:
          (json['depositPaymentLogDTOList'] as List<dynamic>? ?? const [])
              .map((e) => DepositPaymentLog.fromJson(e as Map<String, dynamic>))
              .toList(),
      productRateList: (json['productRateDTOList'] as List<dynamic>? ??
              const [])
          .map((e) => DepositProductRate.fromJson(e as Map<String, dynamic>))
          .toList(),
      projectedInterestNow: json['projectedInterestNow'] as int?,
      maturityAmountProjected: json['maturityAmountProjected'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'accountDTO': account?.toJson(),
        'applicationDTO': application.toJson(),
        'depositPaymentLogDTOList':
            depositPaymentLogList.map((e) => e.toJson()).toList(),
        'productRateDTOList': productRateList.map((e) => e.toJson()).toList(),
        'projectedInterestNow': projectedInterestNow,
        'maturityAmountProjected': maturityAmountProjected
      };
}
