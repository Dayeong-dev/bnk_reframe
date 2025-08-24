// models/account_tx_models.dart
DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

class AccountTransaction {
  final int id;
  final int amount;                 // 원 단위 (+는 입금/CREDIT, -는 출금/DEBIT 표시용은 아래에서 처리)
  final String direction;           // "CREDIT" | "DEBIT"
  final String transactionType;     // "DEPOSIT_PAYMENT" 등
  final DateTime? transactionAt;
  final String? counterpartyAccount;

  AccountTransaction({
    required this.id,
    required this.amount,
    required this.direction,
    required this.transactionType,
    this.transactionAt,
    this.counterpartyAccount,
  });

  factory AccountTransaction.fromJson(Map<String, dynamic> json) => AccountTransaction(
    id: (json['id'] as num).toInt(),
    amount: (json['amount'] as num).toInt(),
    direction: json['direction']?.toString() ?? 'DEBIT',
    transactionType: json['transactionType']?.toString() ?? '',
    transactionAt: _parseDate(json['transactionAt']),
    counterpartyAccount: json['counterpartyAccount']?.toString(),
  );
}

class PagedTx {
  final List<AccountTransaction> items;
  final bool hasMore;
  final int nextPage;
  PagedTx({required this.items, required this.hasMore, required this.nextPage});
}
