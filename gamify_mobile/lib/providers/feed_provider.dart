import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../models/feed_item.dart';
import '../models/post_model.dart';

/// The Home feed: friends' posts and your own, best first, with gaming news worked in (the backend decides
/// the order). Loaded a page at a time as the player scrolls.
class FeedProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final ApiClient _apiClient = ApiClient();

  final List<FeedItem> _items = [];
  // From the last page; null before the first page and at the end
  String? _cursor;
  bool _loadedOnce = false;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _errorMessage;
  // Bumped on refresh so a page that was loading for the old list is ignored
  int _generation = 0;

  List<FeedItem> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _loadedOnce || _errorMessage != null;

  /// Starts again from the top (pull to refresh, first load). New posts only show up after this.
  Future<void> refresh() async {
    _generation++;
    _items.clear();
    _cursor = null;
    _loadedOnce = false;
    _hasMore = true;
    _isLoading = false;
    await loadMore();
  }

  /// Fetches the next page; does nothing if one is already loading or there is no more.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.feed,
        queryParameters: {'size': pageSize, 'cursor': ?_cursor},
      );
      if (generation != _generation) return;
      final List items = response.data['items'] ?? [];
      final seen = _items.map((i) => i.key).toSet();
      // A post whose likes changed while scrolling can rank again further down; show it once
      _items.addAll(items
          .map((e) => FeedItem.fromJson(e))
          .whereType<FeedItem>()
          .where((i) => seen.add(i.key)));
      _cursor = response.data['nextCursor'];
      _hasMore = _cursor != null;
      _loadedOnce = true;
    } on DioException catch (e) {
      if (generation != _generation) return;
      _errorMessage = apiErrorMessage(e, 'Could not load your feed');
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Shows a post's latest likes and comments, e.g. after liking it or coming back from it.
  void updatePost(Post post) {
    final index = _items.indexWhere((i) => i.post?.id == post.id);
    if (index < 0) return;
    _items[index] = FeedItem.post(post);
    notifyListeners();
  }

  void removePost(int postId) {
    final before = _items.length;
    _items.removeWhere((i) => i.post?.id == postId);
    if (_items.length != before) notifyListeners();
  }

  void clear() {
    _generation++;
    _items.clear();
    _cursor = null;
    _loadedOnce = false;
    _hasMore = true;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
