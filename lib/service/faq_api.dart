import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/faq.dart';

class PagedFaq {
  final List<Faq> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  PagedFaq({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory PagedFaq.fromJson(Map<String, dynamic> json) {
    final items =
        (json['content'] as List).map((e) => Faq.fromJson(e)).toList();
    return PagedFaq(
      content: items,
      number: json['number'],
      size: json['size'],
      totalElements: json['totalElements'],
      totalPages: json['totalPages'],
      last: json['last'],
    );
  }
}

class FaqApi {
  final String baseUrl;
  final http.Client _client;

  FaqApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<PagedFaq> fetchFaqs({
    int page = 0,
    int size = 10,
    String? search,
    String? category,
    String sort = 'faqId,asc',
  }) async {
    final uri = Uri.parse('$baseUrl/api/faqs').replace(queryParameters: {
      'page': '$page',
      'size': '$size',
      'sort': sort,
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty && category != '전체')
        'category': category,
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('FAQ 목록 로드 실패: ${res.statusCode}');
    }
    return PagedFaq.fromJson(jsonDecode(res.body));
  }

  Future<Faq> fetchFaqDetail(int id) async {
    final uri = Uri.parse('$baseUrl/api/faqs/$id');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('FAQ 상세 로드 실패: ${res.statusCode}');
    }
    return Faq.fromJson(jsonDecode(res.body));
  }

  Future<List<String>> fetchCategories() async {
    final uri = Uri.parse('$baseUrl/api/faqs/categories');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('카테고리 로드 실패: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List).map((e) => e.toString()).toList();
  }
}
