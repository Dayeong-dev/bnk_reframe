// lib/model/review.dart
class Review {
  final int id;
  final int productId;
  final String content;
  final int? rating;
  final String? authorName;
  final String? createdAt;   // 서버가 ISO 문자열이면 String으로 둬도 OK
  final String? authorId;    // ★ 문자열 비교 안정
  final bool? mine;          // ★ 서버 판정

  Review({
    required this.id,
    required this.productId,
    required this.content,
    this.rating,
    this.authorName,
    this.createdAt,
    this.authorId,
    this.mine,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] as num).toInt(),
      productId: (json['productId'] as num).toInt(),
      content: json['content'] as String,
      rating: json['rating'] == null ? null : (json['rating'] as num).toInt(),
      authorName: json['authorName'] as String?,
      createdAt: json['createdAt']?.toString(),
      authorId: json['authorId']?.toString(),
      mine: json['mine'] as bool?,
    );
  }
}

class MyReview {
  final int id;
  final int productId;
  final String productName;
  final String content;
  final int? rating;
  final dynamic createdAt; // String/epoch/DateTime 허용

  MyReview({
    required this.id,
    required this.productId,
    required this.productName,
    required this.content,
    this.rating,
    this.createdAt,
  });

  factory MyReview.fromJson(Map<String, dynamic> j) => MyReview(
    id: j['id'] as int,
    productId: j['productId'] as int,
    productName: (j['productName'] ?? '') as String,
    content: (j['content'] ?? '') as String,
    rating: (j['rating'] as num?)?.toInt(),
    createdAt: j['createdAt'],
  );
}
