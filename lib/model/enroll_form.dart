import 'package:reframe/model/account.dart';

class EnrollForm {
  int? periodMonths;
  int? paymentAmount;
  int? transferDate;

  String? groupName;
  String? groupType;

  int? fromAccountId;
  int? maturityAccountId;

  String? fromAccountNumber;
  String? maturityAccountNumber;

  EnrollForm({
    this.periodMonths,
    this.paymentAmount,
    this.transferDate,

    this.groupName,
    this.groupType,

    this.fromAccountId,
    this.maturityAccountId,

    this.fromAccountNumber,
    this.maturityAccountNumber,
  });

  @override
  String toString() => 'EnrollForm('
      'periodMonths: $periodMonths, '
      'paymentAmount: $paymentAmount, '
      'transferDate: $transferDate, '
      'groupName: $groupName, '
      'groupType: $groupType, '
      'fromAccountId: $fromAccountId, '
      'maturityAccountId: $maturityAccountId'
      'fromAccountNumber: $fromAccountNumber, '
      'maturityAccountNumber: $maturityAccountNumber'
      ')';

  factory EnrollForm.fromJson(Map<String, dynamic> json) {
    return EnrollForm(
      periodMonths: json['periodMonths'],
      paymentAmount: json['paymentAmount'],
      transferDate: json['transferDate'],
      groupName: json['groupName'],
      groupType: json['groupType'],
      fromAccountId: json['fromAccountId'],
      maturityAccountId: json['maturityAccountId'],
      fromAccountNumber: json['fromAccountNumber'],
      maturityAccountNumber: json['maturityAccountNumber'],
    );
  }

  Map<String, dynamic> toJson() => {
        'periodMonths': periodMonths,
        'paymentAmount': paymentAmount,
        'transferDate': transferDate,
        'groupName': groupName,
        'groupType': groupType,
        'fromAccountId': fromAccountId,
        'maturityAccountId': maturityAccountId
      };
}
