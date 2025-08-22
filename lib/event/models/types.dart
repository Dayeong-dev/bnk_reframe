// types.dart — Fortune DTO들 (Flutter)

// ==== 간단 Flow 인자 ====
typedef FortuneFlowArgs = ({
bool isAgreed,
String? name,
String? birthDate, // yyyymmdd
String? gender,    // "남" / "여"
String? invitedBy,
});

// ==== 요청 DTO ====
class FortuneRequest {
  final String name;
  final String birthDate; // yyyymmdd
  final String gender;    // "남"/"여"
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

// ==== 응답 DTO ====
class FortuneResponse {
  /// 한 문장 "~하기 좋은 하루"
  final String fortune;

  /// 제공된 22개 중 하나 (한국어 라벨)
  final String keyword;

  /// ✅ 부가설명 3문장 (서버가 바로 내려주는 텍스트)
  /// 하위호환을 위해 nullable로 둠
  final String? content;

  /// 추천 상품 2개
  final List<ProductBrief> products;

  const FortuneResponse({
    required this.fortune,
    required this.keyword,
    this.content,
    required this.products,
  });

  factory FortuneResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['products'] as List? ?? [])
        .map((e) => ProductBrief.fromJson(e as Map<String, dynamic>))
        .toList();

    return FortuneResponse(
      fortune: (j['fortune'] as String?) ?? '',
      keyword: (j['keyword'] as String?) ?? '',
      content: j['content'] as String?, // ✅ 추가
      products: list,
    );
  }

  Map<String, dynamic> toJson() => {
    'fortune': fortune,
    'keyword': keyword,
    if (content != null) 'content': content, // ✅ 추가
    'products': products.map((e) => e.toJson()).toList(),
  };

  FortuneResponse copyWith({
    String? fortune,
    String? keyword,
    String? content,
    List<ProductBrief>? products,
  }) {
    return FortuneResponse(
      fortune: fortune ?? this.fortune,
      keyword: keyword ?? this.keyword,
      content: content ?? this.content,
      products: products ?? this.products,
    );
  }
}

// ==== 하위 객체 ====
class ProductBrief {
  final int productId;
  final String name;
  final String category;
  final String? summary;

  const ProductBrief({
    required this.productId,
    required this.name,
    required this.category,
    this.summary,
  });

  factory ProductBrief.fromJson(Map<String, dynamic> j) => ProductBrief(
    productId: j['productId'] as int,
    name: j['name'] as String,
    category: j['category'] as String,
    summary: j['summary'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'category': category,
    if (summary != null) 'summary': summary,
  };
}
