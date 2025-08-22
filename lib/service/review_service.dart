// lib/service/review_service.dart
import 'package:dio/dio.dart';
import 'package:reframe/core/interceptors/http.dart';
import 'package:reframe/model/review.dart';
import 'package:reframe/utils/recent_my_review.dart'; // ✅ 추가

class ReviewService {
  static Future<List<Review>> fetchReviews(int productId) async {
    final res = await dio.get('/mobile/products/$productId/reviews');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Review.fromJson(e)).toList();
    }
    return <Review>[];
  }

  static Future<void> createReview({
    required int productId,
    required String content,
    required int rating,
  }) async {
    // ✅ 전송 직전에 "내가 방금 쓴 리뷰" 버퍼에 기록
    RecentMyReviewBuffer.I.markSubmitted(
      productId: productId,
      contentRaw: content,
      rating: rating,
      // ttl: Duration(seconds: 10), // 필요시 조정
    );

    await dio.post(
      '/mobile/reviews',
      data: {
        'productId': productId,
        'content': content,
        'rating': rating,
      },
    );
  }
}
