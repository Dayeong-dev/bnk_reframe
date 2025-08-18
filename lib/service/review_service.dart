import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env/app_endpoints.dart';
import '../model/review.dart';

class ReviewService {
  static Future<List<Review>> fetchReviews(int productId) async {
    final uri = Uri.parse('${AppEndpoints.apiPrefix}/products/$productId/reviews');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw 'HTTP ${res.statusCode}: ${res.body}';
    }
    final List data = jsonDecode(res.body) as List;
    return data.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createReview({
    required int productId,
    required String content,
    int? rating,
  }) async {
    final uri = Uri.parse('${AppEndpoints.apiPrefix}/reviews');
    final body = jsonEncode({
      'productId': productId,
      'content': content,
      if (rating != null) 'rating': rating,
    });
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (res.statusCode != 201) {
      throw 'HTTP ${res.statusCode}: ${res.body}';
    }
  }
}
