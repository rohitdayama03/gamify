import 'connection_model.dart';

DateTime? _parseDate(dynamic value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

enum PostType { text, image, video }

class Post {
  final int id;
  final PlayerSummary author;
  final PostType type;
  // The post itself for text posts, the caption otherwise
  final String? text;
  // Signed S3 links valid for about an hour, so re-fetch the post rather than keeping these around
  final String? mediaPath;
  final String? thumbnailPath;
  final int? mediaWidth;
  final int? mediaHeight;
  final int likeCount;
  // True when the signed-in player likes it
  final bool likedByMe;
  final int commentCount;
  // 3 per comment (replies included) plus 1 per like
  final int engagementScore;
  // How the feed ranks it: recency plus engagement, both fading with age (as of when it was fetched)
  final double score;
  // True for the signed-in player's own posts
  final bool mine;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.author,
    required this.type,
    this.text,
    this.mediaPath,
    this.thumbnailPath,
    this.mediaWidth,
    this.mediaHeight,
    required this.likeCount,
    required this.likedByMe,
    required this.commentCount,
    this.engagementScore = 0,
    this.score = 0,
    required this.mine,
    required this.createdAt,
  });

  /// Width / height for laying out the media before it loads; square when unknown.
  double get aspectRatio {
    final w = mediaWidth, h = mediaHeight;
    if (w == null || h == null || w <= 0 || h <= 0) return 1;
    // Keep very tall or very wide media from taking over the screen, like Instagram's 4:5 to 1.91:1
    return (w / h).clamp(0.8, 1.91);
  }

  Post copyWith({int? likeCount, bool? likedByMe, int? commentCount}) => Post(
        id: id,
        author: author,
        type: type,
        text: text,
        mediaPath: mediaPath,
        thumbnailPath: thumbnailPath,
        mediaWidth: mediaWidth,
        mediaHeight: mediaHeight,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        commentCount: commentCount ?? this.commentCount,
        engagementScore: engagementScore,
        score: score,
        mine: mine,
        createdAt: createdAt,
      );

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      author: PlayerSummary.fromJson(json['author']),
      type: PostType.values.byName((json['type'] as String).toLowerCase()),
      text: json['text'],
      mediaPath: json['mediaUrl'],
      thumbnailPath: json['thumbnailUrl'],
      mediaWidth: json['mediaWidth'],
      mediaHeight: json['mediaHeight'],
      likeCount: json['likeCount'] ?? 0,
      likedByMe: json['likedByMe'] ?? false,
      commentCount: json['commentCount'] ?? 0,
      engagementScore: json['engagementScore'] ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      mine: json['mine'] ?? false,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class PostComment {
  final int id;
  final int postId;
  // The top-level comment this replies to; null for top-level comments
  final int? parentId;
  final PlayerSummary author;
  final String content;
  final bool mine;
  // The comment's author and the post's author may delete it
  final bool canDelete;
  final DateTime createdAt;
  // Oldest first; always empty for replies
  final List<PostComment> replies;

  PostComment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.author,
    required this.content,
    required this.mine,
    required this.canDelete,
    required this.createdAt,
    this.replies = const [],
  });

  PostComment withReplies(List<PostComment> replies) => PostComment(
        id: id,
        postId: postId,
        parentId: parentId,
        author: author,
        content: content,
        mine: mine,
        canDelete: canDelete,
        createdAt: createdAt,
        replies: replies,
      );

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final List replies = json['replies'] ?? [];
    return PostComment(
      id: json['id'],
      postId: json['postId'],
      parentId: json['parentId'],
      author: PlayerSummary.fromJson(json['author']),
      content: json['content'],
      mine: json['mine'] ?? false,
      canDelete: json['canDelete'] ?? false,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      replies: replies.map((e) => PostComment.fromJson(e)).toList(),
    );
  }
}
