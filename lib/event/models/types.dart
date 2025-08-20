// 간단 DTO들

typedef FortuneFlowArgs = ({
bool isAgreed,
String? name,
String? birthDate, // yyyymmdd
String? gender,    // "남" / "여"
String? invitedBy,
});

class FortuneRequest {
  final String name;
  final String birthDate; // yyyymmdd
  final String gender;    // 남/여
  final DateTime date;
  final String? invitedBy;
  FortuneRequest({
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.date,
    this.invitedBy,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'birthDate': birthDate,
    'gender': gender,
    'date': date.toIso8601String(),
    if (invitedBy != null) 'invitedBy': invitedBy,
  };
}

class FortuneResponse {
  final String fortune;   // 한 문장 "~하기 좋은 하루"
  final String keyword;   // 제공된 22개 중 하나
  final List<ProductBrief> products; // 추천 2개
  FortuneResponse({required this.fortune, required this.keyword, required this.products});

  factory FortuneResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['products'] as List? ?? [])
        .map((e) => ProductBrief.fromJson(e as Map<String, dynamic>))
        .toList();
    return FortuneResponse(
      fortune: j['fortune'] ?? '',
      keyword: j['keyword'] ?? '',
      products: list,
    );
  }
}

class ProductBrief {
  final int productId;
  final String name;
  final String category;
  final String? summary;
  ProductBrief({required this.productId, required this.name, required this.category, this.summary});

  factory ProductBrief.fromJson(Map<String, dynamic> j) => ProductBrief(
    productId: j['productId'],
    name: j['name'],
    category: j['category'],
    summary: j['summary'],
  );
}
