import 'common.dart';

class DepositProductRate {
  final int? fromMonth;
  final int? toMonth;
  final double? rate; // 예: 3.200

  DepositProductRate({this.fromMonth, this.toMonth, this.rate});

  factory DepositProductRate.fromJson(Map<String, dynamic> json) {
    return DepositProductRate(
      fromMonth: parseInt(json['fromMonth']),
      toMonth: parseInt(json['toMonth']),
      rate: parseDouble(json['rate']),
    );
  }

  Map<String, dynamic> toJson() => {
    'fromMonth': fromMonth,
    'toMonth': toMonth,
    'rate': rate,
  };
}
