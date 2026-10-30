import 'news_item.dart';
import 'post_model.dart';

/// One entry in the Home feed: a friend's (or your own) post, or a news story.
class FeedItem {
  final Post? post;
  final NewsItem? news;

  const FeedItem.post(Post this.post) : news = null;
  const FeedItem.news(NewsItem this.news) : post = null;

  bool get isPost => post != null;

  /// Tells items apart across pages, since a post and a news story can share an id.
  String get key => isPost ? 'post-${post!.id}' : 'news-${news!.id}';

  /// Null for an entry this version of the app doesn't know.
  static FeedItem? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'POST':
        return FeedItem.post(Post.fromJson(json['post']));
      case 'NEWS':
        return FeedItem.news(NewsItem.fromJson(json['news']));
    }
    return null;
  }
}
