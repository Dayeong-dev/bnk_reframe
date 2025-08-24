DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

double? parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is num) return v.toInt();
  return null;
}

enum ApplicationStatus { started, closed, canceled }

ApplicationStatus? applicationStatus(dynamic v) {
  if (v == null) return null;
  final s = v.toString().toLowerCase();
  return ApplicationStatus.values.firstWhere(
        (e) => e.name == s,
    orElse: () => ApplicationStatus.started,
  );
}

enum PaymentStatus { unpaid, paid }
PaymentStatus? paymentStatus(dynamic v) {
  if (v == null) return null;
  final s = v.toString().toLowerCase();
  return PaymentStatus.values.firstWhere(
        (e) => e.name == s,
    orElse: () => PaymentStatus.unpaid,
  );
}
