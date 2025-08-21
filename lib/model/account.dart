enum AccountType {
  demand,		// 입출금
  product		// 예적금
}

enum AccountStatus {
  active,		// 활성화
  closed,		// 비 활성화
  suspended // 정지
}

class Account {
  final int id;
  final String accountNumber;
  final String bankName;
  final AccountType accountType;
  final int balance;
  final String? accountName;
  final int isDefault;
  final AccountStatus status;
  final DateTime createAt;

  Account({
    required this.id,
    required this.accountNumber,
    required this.bankName,
    required this.accountType,
    required this.balance,
    this.accountName,
    required this.isDefault,
    required this.status,
    required this.createAt
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as int,
    accountNumber: json['accountNumber'],
    bankName: json['bankName'],
    accountType: json['accountType'] as AccountType,
    balance: json['balance'],
    accountName: json['accountName'],
    isDefault: json['isDefault'],
    status: json['status'] as AccountStatus,
    createAt: json['createAt'] as DateTime,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "accountNumber": accountNumber,
    "bankName": bankName,
    "accountType": accountType,
    "balance": balance,
    "accountName": accountName,
    "isDefault": isDefault,
    "status": status,
    "createAt": createAt
  };
}