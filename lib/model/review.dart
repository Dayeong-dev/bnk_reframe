class Review {
  final int id;
  final int productId;
  final String content;
  final int? rating;
  final String? authorName;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.productId,
    required this.content,
    required this.createdAt,
    this.rating,
    this.authorName,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as int,
    productId: (j['productId'] as num).toInt(),
    content: j['content'] as String,
    rating: j['rating'] == null ? null : (j['rating'] as num).toInt(),
    authorName: j['authorName'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
