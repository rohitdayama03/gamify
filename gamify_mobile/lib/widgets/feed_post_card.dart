import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post_model.dart';
import '../providers/feed_provider.dart';
import '../providers/post_provider.dart';
import '../screens/posts/post_detail_screen.dart';
import 'post_view.dart';

/// A post in the Home feed. Likes right here; the caption and comment button open the post.
class FeedPostCard extends StatefulWidget {
  final Post post;

  const FeedPostCard({super.key, required this.post});

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  bool _liking = false;

  FeedProvider get _feed => Provider.of<FeedProvider>(context, listen: false);

  Future<void> _setLiked(bool liked) async {
    final before = widget.post;
    if (_liking || before.likedByMe == liked) return;
    _liking = true;
    // Show the like straight away, and put it back if the backend says no
    _feed.updatePost(before.copyWith(likedByMe: liked, likeCount: (before.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30)));
    final posts = Provider.of<PostProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final result = await posts.setLiked(before.id, liked);
    _liking = false;
    if (!mounted) return;
    _feed.updatePost(result == null
        ? before
        : before.copyWith(likedByMe: result.liked, likeCount: result.likeCount));
    if (result == null) {
      messenger.showSnackBar(SnackBar(content: Text(posts.errorMessage ?? 'Could not like the post')));
    }
  }

  Future<void> _open() async {
    final posts = Provider.of<PostProvider>(context, listen: false);
    final feed = _feed;
    final deleted = await PostDetailScreen.open(context, widget.post);
    if (deleted == true) {
      feed.removePost(widget.post.id);
      return;
    }
    // Likes and comments may have changed while it was open
    final latest = await posts.fetchPost(widget.post.id);
    if (latest != null) feed.updatePost(latest);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: PostView(
        post: widget.post,
        onToggleLike: () => _setLiked(!widget.post.likedByMe),
        onDoubleTapLike: () => _setLiked(true),
        onComment: _open,
        onOpen: _open,
      ),
    );
  }
}
