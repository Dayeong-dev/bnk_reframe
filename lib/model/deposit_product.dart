import 'package:reframe/model/document.dart';

class DepositProduct {
  final int productId;
  final String name;
  final String? category;
  final String? purpose;
  final String summary;
  final String detail; // ✅ HTML 문자열
  final String modalDetail; // ✅ HTML
  final String modalRate; // ✅ HTML
  final double maxRate;
  final double minRate;
  final int period;
  final int viewCount;
  final String imageUrl;

  final Document? term;
  final Document? manual;
  final String? paymentCycle;
  final int? minPeriodMonths;
  final int? maxPeriodMonths;
  final String? termList;
  final String? termMode;

  DepositProduct({
    required this.productId,
    required this.name,
    this.category,
    this.purpose,
    required this.summary,
    required this.detail,
    required this.modalDetail,
    required this.modalRate,
    required this.maxRate,
    required this.minRate,
    required this.period,
    required this.viewCount,
    required this.imageUrl,

    this.term,
    this.manual,
    this.paymentCycle,
    this.minPeriodMonths,
    this.maxPeriodMonths,
    this.termList,
    this.termMode,
  });

  factory DepositProduct.fromJson(Map<String, dynamic> json) {
    return DepositProduct(
      productId: json['productId'],
      name: json['name'],
      category: json['category'],
      purpose: json['purpose'],
      summary: json['summary'] ?? '',
      detail: json['detail'] ?? '',
      modalDetail: json['modalDetail'] ?? '',
      modalRate: json['modalRate'] ?? '',
      maxRate: (json['maxRate'] ?? 0).toDouble(),
      minRate: (json['minRate'] ?? 0).toDouble(),
      period: json['period'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',

      term: json['term'] == null ? null : Document.fromJson(json['term']),
      manual: json['manual'] == null ? null : Document.fromJson(json['manual']),
      paymentCycle: json['paymentCycle'] ?? '',
      minPeriodMonths: json['minPeriodMonths'] ?? 0,
      maxPeriodMonths: json['maxPeriodMonths'] ?? 0,
      termList: json['termList'] ?? '',
      termMode: json['termMode'] ?? '',
    );
  }
}
