import 'package:reframe/constants/api_constants.dart'; // apiBaseUrl 사용
import 'package:reframe/model/review.dart';
import 'package:reframe/core/interceptors/http.dart'; // dio 공용 인스턴스 (JWT 포함)

class ReviewService {
  // ★ 리뷰 API는 /mobile 접두어 사용 (env/app_endpoints.dart 수정 없이 해결)
  static String get _mobileBase => '$apiBaseUrl/mobile';

  static Future<List<Review>> fetchReviews(int productId) async {
    final res = await dio.get('$_mobileBase/products/$productId/reviews');
    // 200 OK만 정상 처리
    if (res.statusCode != 200) {
      throw 'HTTP ${res.statusCode}: ${res.data}';
    }
    final List data = res.data as List;
    return data.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createReview({
    required int productId,
    required String content,
    int? rating,
  }) async {
    final res = await dio.post(
      '$_mobileBase/reviews',
      data: {
        'productId': productId,
        'content': content,
        if (rating != null) 'rating': rating,
      },
    );
    if (res.statusCode != 201) {
      throw 'HTTP ${res.statusCode}: ${res.data}';
    }
  }
}
