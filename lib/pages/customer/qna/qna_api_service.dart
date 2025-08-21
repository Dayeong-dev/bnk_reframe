import '../../../core/interceptors/http.dart';
import 'qna_model.dart';

class QnaApiService {
  final String baseUrl;

  QnaApiService({required this.baseUrl});

  Future<List<Qna>> fetchMyQnaList() async {
    final res = await dio.get('$baseUrl/mobile/qna');
    final data = (res.data as List).cast<Map<String, dynamic>>();
    return data.map((e) => Qna.fromJson(e)).toList();
  }

  Future<Qna> fetchDetail(int qnaId) async {
    final res = await dio.get('$baseUrl/mobile/qna/$qnaId');
    return Qna.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Qna> create({
    required String category,
    required String title,
    required String content,
  }) async {
    final res = await dio.post('$baseUrl/mobile/qna', data: {
      'category': category,
      'title': title,
      'content': content,
    });
    return Qna.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Qna> update({
    required int qnaId,
    required String category,
    required String title,
    required String content,
  }) async {
    final res = await dio.put('$baseUrl/mobile/qna/$qnaId', data: {
      'category': category,
      'title': title,
      'content': content,
    });
    return Qna.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(int qnaId) async {
    await dio.delete('$baseUrl/mobile/qna/$qnaId');
  }
}
