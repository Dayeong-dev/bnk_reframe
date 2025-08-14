import 'package:flutter/foundation.dart';
import '../model/faq.dart';
import '../service/faq_api.dart';

class FaqStore extends ChangeNotifier {
  FaqStore({required this.api});
  final FaqApi api;

  final List<Faq> _items = [];
  List<Faq> get items => List.unmodifiable(_items);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLast = false;
  bool get isLast => _isLast;

  int _page = 0;
  final int _size = 10;

  String _search = '';
  String get search => _search;

  String _category = '전체';
  String get category => _category;

  List<String> _categories = const ['전체'];
  List<String> get categories => _categories;

  List<String> get suggestions {
    final set = <String>{};
    for (final f in _items) {
      final q = f.question ?? '';
      if (q.isNotEmpty) set.add(q);
    }
    return set.toList();
  }

  Future<void> init() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      try {
        final cats = await api.fetchCategories();
        _categories = ['전체', ...cats];
      } catch (_) {
        _categories = const ['전체'];
      }
      _page = 0;
      _isLast = false;
      _items.clear();

      final pageRes = await api.fetchFaqs(
        page: _page, size: _size, search: _search, category: _category,
      );
      _items.addAll(pageRes.content);
      _isLast = pageRes.last;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _page = 0;
    _isLast = false;
    _items.clear();
    notifyListeners();
    await init();
  }

  Future<void> loadNext() async {
    if (_isLoading || _isLast) return;
    _isLoading = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final pageRes = await api.fetchFaqs(
        page: next, size: _size, search: _search, category: _category,
      );
      _items.addAll(pageRes.content);
      _page = next;
      _isLast = pageRes.last;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void onSearchChanged(String text) {
    final v = text.trim();
    if (v == _search) return;
    _search = v;
    refresh();
  }

  void onCategoryChanged(String cat) {
    if (cat == _category) return;
    _category = cat;
    refresh();
  }
}
