
import 'package:reframe/model/user.dart';

enum AccountType {
  demand, // 입출금
  product // 예적금
}

enum AccountStatus {
  active, // 활성화
  closed, // 비 활성화
  suspended // 정지
}

enum ProductType {
  deposit,
  savings,
  demand_free
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty)
    return DateTime.tryParse(v); // "2025-08-18T05:02:43.840448"
  if (v is int)
    return DateTime.fromMillisecondsSinceEpoch(v); // epoch millis 대비
  return null;
}

class Account {
  final int id;
  final String accountNumber;
  final User user;
  final String bankName;
  final AccountType accountType;
  final int balance;
  final String? accountName;
  final int isDefault;
  final AccountStatus status;
  final DateTime? createAt;
  final ProductType? productType;

  Account(
      {required this.id,
      required this.accountNumber,
      required this.user,
      required this.bankName,
      required this.accountType,
      required this.balance,
      this.accountName,
      required this.isDefault,
      required this.status,
      this.createAt,
      this.productType});

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as int,
        accountNumber: json['accountNumber'],
        bankName: json['bankName'],
        user: User.fromJson(json['user']),
        accountType: AccountType.values
            .byName(json['accountType'].toString().toLowerCase()),
        balance: json['balance'],
        accountName: json['accountName'],
        isDefault: json['isDefault'],
        status: AccountStatus.values
            .byName(json['status'].toString().toLowerCase()),
        createAt: _parseDate(json['createAt']),
        productType: json['productType'] != null ? ProductType.values.byName(json['productType'].toString().toLowerCase()) : null
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "accountNumber": accountNumber,
        "user": user,
        "bankName": bankName,
        "accountType": accountType,
        "balance": balance,
        "accountName": accountName,
        "isDefault": isDefault,
        "status": status,
        "createAt": createAt,
        "productType": productType
      };
}
