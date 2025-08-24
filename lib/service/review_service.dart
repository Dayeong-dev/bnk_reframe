// lib/service/review_service.dart
import 'package:dio/dio.dart';
import 'package:reframe/core/interceptors/http.dart';
import 'package:reframe/model/review.dart';
import 'package:reframe/utils/recent_my_review.dart';

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
    RecentMyReviewBuffer.I.markSubmitted(
      productId: productId,
      contentRaw: content,
      rating: rating,
    );

    await dio.post(
      '/mobile/reviews',
      data: {'productId': productId, 'content': content, 'rating': rating},
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  static Future<List<MyReview>> fetchMyReviews() async {
    final res = await dio.get('/mobile/reviews/me');
    final data = res.data;
    if (data is List) {
      return data.map((e) => MyReview.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return <MyReview>[];
  }

  // ★ 내 리뷰 수정
  static Future<void> updateReview({
    required int reviewId,
    String? content,
    int? rating,
  }) async {
    await dio.put(
      '/mobile/reviews/$reviewId',
      data: {'content': content, 'rating': rating},
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  // ★ 내 리뷰 삭제
  static Future<void> deleteReview(int reviewId) async {
    await dio.delete('/mobile/reviews/$reviewId');
  }
}
