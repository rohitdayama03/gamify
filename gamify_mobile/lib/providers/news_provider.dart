import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../models/news_item.dart';

/// Gaming news for the Home feed, newest first, loaded a page at a time as the player scrolls.
class NewsProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final ApiClient _apiClient = ApiClient();

  final List<NewsItem> _items = [];
  int _nextPage = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _errorMessage;
  // Bumped on refresh so a page that was loading for the old list is ignored
  int _generation = 0;

  List<NewsItem> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _nextPage > 0 || _errorMessage != null;

  /// Reloads from the newest item (pull to refresh, first load).
  Future<void> refresh() async {
    _generation++;
    _items.clear();
    _nextPage = 0;
    _hasMore = true;
    _isLoading = false;
    await loadMore();
  }

  /// Fetches the next (older) page; does nothing if one is already loading or there is no more.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.news,
        queryParameters: {'page': _nextPage, 'size': pageSize},
      );
      if (generation != _generation) return;
      final List content = response.data['content'] ?? [];
      final seen = _items.map((n) => n.id).toSet();
      // Skip repeats in case new stories arrived and shifted the pages while scrolling
      _items.addAll(content.map((e) => NewsItem.fromJson(e)).where((n) => !seen.contains(n.id)));
      _hasMore = response.data['last'] != true && content.isNotEmpty;
      _nextPage++;
    } on DioException catch (e) {
      if (generation != _generation) return;
      _errorMessage = apiErrorMessage(e, 'Could not load news');
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    _items.clear();
    _nextPage = 0;
    _hasMore = true;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
