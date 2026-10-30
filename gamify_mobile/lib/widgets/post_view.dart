import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/time_format.dart';
import '../models/post_model.dart';
import '../screens/player/player_profile_screen.dart';
import 'player_avatar.dart';
import 'post_media.dart';

/// A post's author, media, caption and like/comment row, as shown on its own page and in the feed.
class PostView extends StatelessWidget {
  final Post post;
  final VoidCallback onToggleLike;
  final VoidCallback onDoubleTapLike;
  final VoidCallback onComment;
  // In the feed: tapping the caption opens the post, and long captions are cut short
  final VoidCallback? onOpen;

  const PostView({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onDoubleTapLike,
    required this.onComment,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final mediaPath = post.mediaPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OpenProfileOnTap(
          playerId: author.playerId,
          username: author.username,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                PlayerAvatar(
                  name: author.username,
                  url: author.avatarUrl,
                  radius: 18,
                  textStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18 * 0.9),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(author.username, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(timeAgo(post.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (post.type == PostType.image && mediaPath != null)
          _DoubleTapToLike(
            onLike: onDoubleTapLike,
            child: AspectRatio(aspectRatio: post.aspectRatio, child: PostNetworkImage(url: mediaPath)),
          ),
        if (post.type == PostType.video && mediaPath != null)
          PostVideoPlayer(url: mediaPath, thumbnailUrl: post.thumbnailPath, aspectRatio: post.aspectRatio),
        if (post.text != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: onOpen == null
                ? SelectableText(post.text!, style: _textStyle)
                : GestureDetector(
                    onTap: onOpen,
                    child: Text(post.text!, maxLines: 6, overflow: TextOverflow.ellipsis, style: _textStyle),
                  ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: post.likedByMe ? 'Unlike' : 'Like',
                onPressed: onToggleLike,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: post.likedByMe
                      ? const Icon(Icons.favorite, key: ValueKey('liked'), color: AppColors.like)
                      : const Icon(Icons.favorite_border, key: ValueKey('not-liked'), color: AppColors.textPrimary),
                ),
              ),
              Text(_count(post.likeCount, 'like'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Comment',
                onPressed: onComment,
                icon: const Icon(Icons.mode_comment_outlined, color: AppColors.textPrimary),
              ),
              Text(_count(post.commentCount, 'comment'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle get _textStyle => TextStyle(fontSize: post.type == PostType.text ? 18 : 15, height: 1.4);

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
}

/// Likes on a double-tap, flashing a big heart over the child.
class _DoubleTapToLike extends StatefulWidget {
  final VoidCallback onLike;
  final Widget child;

  const _DoubleTapToLike({required this.onLike, required this.child});

  @override
  State<_DoubleTapToLike> createState() => _DoubleTapToLikeState();
}

class _DoubleTapToLikeState extends State<_DoubleTapToLike> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  // Pops in, holds, then fades
  late final _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
  ]).animate(_controller);
  late final _opacity = TweenSequence([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () {
        widget.onLike();
        _controller.forward(from: 0);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _controller.isAnimating
                  ? Opacity(
                      opacity: _opacity.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: const Icon(Icons.favorite, color: Colors.white, size: 96,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 16)]),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
