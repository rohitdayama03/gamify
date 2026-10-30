import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../core/api/direct_upload.dart';
import '../models/post_model.dart';

/// Size limits, matching the backend (app.media.*). Checked before uploading so players aren't kept waiting.
class PostLimits {
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 50 * 1024 * 1024;
  static const Duration maxVideoDuration = Duration(seconds: 60);
  static const int maxTextLength = 2200;
  static const int maxCommentLength = 1000;
  // Longest side of an image after editing; larger photos are scaled down
  static const int maxImageSide = 2048;
}

/// A page of a player's posts.
typedef PostPage = ({int total, List<Post> posts});

class PostProvider extends ChangeNotifier {
  // Matches the backend page sizes; a full page means more may exist
  static const int postsPageSize = 18;
  static const int commentsPageSize = 30;

  final ApiClient _apiClient = ApiClient();

  String? _errorMessage;
  bool _posting = false;
  // Bumped whenever the signed-in player adds or deletes a post, so profile grids reload
  int _postsVersion = 0;

  String? get errorMessage => _errorMessage;
  int get postsVersion => _postsVersion;

  /// Media links from the API are signed S3 URLs: complete, valid for about an hour, fetched without the login token.
  static String mediaUrl(String url) => url;

  /// True while a post is being uploaded or committed; players post one thing at a time.
  bool get isPosting => _posting;

  /// Posts in three steps, matching the backend:
  ///  1. ask the backend for signed upload links for the post's files (the media, plus a thumbnail for videos),
  ///  2. upload the files straight to S3, reporting 0–1 through [onProgress],
  ///  3. commit the post, which the backend saves only after checking the uploaded files.
  /// Returns the saved post, or null with [errorMessage] set if any step fails. Only one post at a time:
  /// the backend refuses a second, and so does this.
  Future<Post?> createPost({
    required PostType type,
    String? text,
    Uint8List? mediaBytes,
    String? mediaContentType,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
    ValueChanged<double>? onProgress,
  }) async {
    if (_posting) {
      _errorMessage = "You're already posting something. Wait for it to finish, then try again.";
      return null;
    }
    _posting = true;
    notifyListeners();
    var uploadStarted = false;
    try {
      String? mediaKey;
      String? thumbnailKey;
      if (mediaBytes != null) {
        final tickets = await _startUpload([
          (kind: type == PostType.video ? 'VIDEO' : 'IMAGE', contentType: mediaContentType!, size: mediaBytes.length),
          if (thumbnailBytes != null) (kind: 'THUMBNAIL', contentType: 'image/jpeg', size: thumbnailBytes.length),
        ]);
        if (tickets == null) return null;
        uploadStarted = true;

        // The thumbnail is tiny, so progress follows the main file
        if (!await _upload(tickets[0], mediaBytes, onProgress)) return null;
        if (thumbnailBytes != null && !await _upload(tickets[1], thumbnailBytes, null)) return null;
        mediaKey = tickets[0].key;
        thumbnailKey = thumbnailBytes == null ? null : tickets[1].key;
      }

      final response = await _apiClient.dio.post(ApiEndpoints.posts, data: {
        'type': type.name.toUpperCase(),
        'text': text,
        'mediaKey': mediaKey,
        'thumbnailKey': thumbnailKey,
        'width': width,
        'height': height,
      });
      uploadStarted = false; // committed: nothing to cancel
      _errorMessage = null;
      _postsVersion++;
      return Post.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('Could not commit post: ${e.response?.statusCode} ${e.response?.data ?? e.message}');
      _errorMessage = apiErrorMessage(e, 'Could not share your post');
      return null;
    } finally {
      // A failed post shouldn't block the next try: drop its uploads on the backend
      if (uploadStarted) await _cancelUpload();
      _posting = false;
      notifyListeners();
    }
  }

  Future<List<UploadTicket>?> _startUpload(List<({String kind, String contentType, int size})> files) async {
    try {
      final response = await _apiClient.dio.post(ApiEndpoints.postUploads, data: {
        'files': [
          for (final f in files) {'kind': f.kind, 'contentType': f.contentType, 'size': f.size},
        ],
      });
      return UploadTicket.listFromSession(response.data);
    } on DioException catch (e) {
      debugPrint('Could not start upload: ${e.response?.statusCode} ${e.response?.data ?? e.message}');
      _errorMessage = apiErrorMessage(e, 'Could not start the upload');
      return null;
    }
  }

  Future<void> _cancelUpload() async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.postUploads);
    } on DioException catch (_) {
      // The backend lets the next post start once the upload links expire anyway
    }
  }

  Future<bool> _upload(UploadTicket ticket, Uint8List bytes, ValueChanged<double>? onProgress) async {
    final error = await DirectUpload.put(ticket, bytes, onProgress: onProgress);
    if (error != null) _errorMessage = error;
    return error == null;
  }

  /// A player's posts, newest first; pass the last post's id as [beforeId] for the next page.
  Future<PostPage?> fetchPlayerPosts(int playerId, {int? beforeId}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.playerPosts(playerId),
        queryParameters: {'beforeId': ?beforeId},
      );
      _errorMessage = null;
      final List posts = response.data['posts'] ?? [];
      return (total: (response.data['total'] ?? 0) as int, posts: posts.map((e) => Post.fromJson(e)).toList());
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load posts');
      return null;
    }
  }

  Future<Post?> fetchPost(int postId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.post(postId));
      _errorMessage = null;
      return Post.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load the post');
      return null;
    }
  }

  Future<bool> deletePost(int postId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.post(postId));
      _errorMessage = null;
      _postsVersion++;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not delete the post');
      return false;
    }
  }

  /// Likes or unlikes the post; returns the like as it now stands, or null if the request failed.
  Future<({bool liked, int likeCount})?> setLiked(int postId, bool liked) async {
    try {
      final response = liked
          ? await _apiClient.dio.put(ApiEndpoints.postLike(postId))
          : await _apiClient.dio.delete(ApiEndpoints.postLike(postId));
      _errorMessage = null;
      return (liked: response.data['liked'] as bool, likeCount: (response.data['likeCount'] ?? 0) as int);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, liked ? 'Could not like the post' : 'Could not unlike the post');
      return null;
    }
  }

  /// Top-level comments oldest first, each with its replies; pass the last one's id as [afterId] for more.
  Future<List<PostComment>?> fetchComments(int postId, {int? afterId}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.postComments(postId),
        queryParameters: {'afterId': ?afterId},
      );
      _errorMessage = null;
      return ((response.data ?? []) as List).map((e) => PostComment.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load comments');
      return null;
    }
  }

  /// Comments on the post, or replies to [parentId].
  Future<PostComment?> addComment(int postId, String content, {int? parentId}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.postComments(postId),
        data: {'content': content, 'parentId': parentId},
      );
      _errorMessage = null;
      return PostComment.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Comment not posted');
      return null;
    }
  }

  Future<bool> deleteComment(int commentId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.comment(commentId));
      _errorMessage = null;
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not delete the comment');
      return false;
    }
  }
}

