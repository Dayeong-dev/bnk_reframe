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

  @override
  String toString() => 'EnrollForm('
      'periodMonths: $periodMonths, '
      'paymentAmount: $paymentAmount, '
      'transferDate: $transferDate, '
      'groupName: $groupName, '
      'groupType: $groupType, '
      'fromAccountId: $fromAccountId, '
      'maturityAccountId: $maturityAccountId'
      ')';

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
