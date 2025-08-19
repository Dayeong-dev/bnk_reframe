class EnrollForm {
  int? periodMonths;
  int? paymentAmount;
  int? transferDate;

  String? groupName;
  String? groupType;

  String? fromAccountId;
  String? maturityAccountId;

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
}