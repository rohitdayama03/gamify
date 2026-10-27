import 'game.dart';

/// A gaming headline from the backend; the full article lives on the publisher's site at [link].
class NewsItem {
  final int id;
  final String title;
  final String? summary;
  final String? imageUrl;
  // A video (e.g. on YouTube) rather than an article
  final bool video;
  final String link;
  final String? category;
  final String? author;
  final String source;
  // Set when the story is about one of GAMIFY's games
  final Game? game;
  final DateTime publishedAt;

  NewsItem({
    required this.id,
    required this.title,
    this.summary,
    this.imageUrl,
    this.video = false,
    required this.link,
    this.category,
    this.author,
    required this.source,
    this.game,
    required this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      imageUrl: json['imageUrl'],
      video: json['video'] ?? false,
      link: json['link'],
      category: json['category'],
      author: json['author'],
      source: json['source'] ?? '',
      game: Game.fromApi(json['game']),
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}
