import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/post_model.dart';
import '../providers/post_provider.dart';
import '../screens/posts/create_post_screen.dart';
import '../screens/posts/post_detail_screen.dart';
import 'post_media.dart';

/// A player's posts as a 3-column grid, newest first, loading more as you scroll.
/// On your own profile it starts with a New post button.
class PlayerPostsGrid extends StatefulWidget {
  final int playerId;
  final bool isMe;
  final String emptyText;

  const PlayerPostsGrid({super.key, required this.playerId, required this.isMe, required this.emptyText});

  @override
  State<PlayerPostsGrid> createState() => _PlayerPostsGridState();
}

class _PlayerPostsGridState extends State<PlayerPostsGrid> with AutomaticKeepAliveClientMixin {
  List<Post>? _posts;
  int _total = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _error;
  int _seenVersion = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _seenVersion = Provider.of<PostProvider>(context, listen: false).postsVersion;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Own posts were added or deleted somewhere: reload
    final version = Provider.of<PostProvider>(context).postsVersion;
    if (widget.isMe && version != _seenVersion) {
      _seenVersion = version;
      _load();
    }
  }

  Future<void> _load() async {
    final provider = Provider.of<PostProvider>(context, listen: false);
    final page = await provider.fetchPlayerPosts(widget.playerId);
    if (!mounted) return;
    setState(() {
      _error = page == null ? provider.errorMessage : null;
      if (page != null) {
        _posts = page.posts;
        _total = page.total;
        _hasMore = page.posts.length >= PostProvider.postsPageSize;
      }
    });
  }

  Future<void> _loadMore() async {
    final posts = _posts;
    if (_loadingMore || !_hasMore || posts == null || posts.isEmpty) return;
    setState(() => _loadingMore = true);
    final page = await Provider.of<PostProvider>(context, listen: false).fetchPlayerPosts(widget.playerId, beforeId: posts.last.id);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (page != null) {
        _posts = [...posts, ...page.posts];
        _total = page.total;
        _hasMore = page.posts.length >= PostProvider.postsPageSize;
      }
    });
  }

  Future<void> _open(Post post) async {
    await PostDetailScreen.open(context, post);
    // Comment counts may have changed; deletions of own posts reload through postsVersion
    if (mounted && !widget.isMe) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final posts = _posts;
    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) _loadMore();
          return false;
        },
        child: CustomScrollView(
          slivers: [
            if (widget.isMe)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      // One post at a time
                      onPressed: Provider.of<PostProvider>(context).isPosting ? null : () => CreatePostScreen.open(context),
                      icon: const Icon(Icons.add_box_outlined),
                      label: Text(Provider.of<PostProvider>(context).isPosting ? 'Posting…' : 'New post'),
                    ),
                  ),
                ),
              ),
            if (posts == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                            TextButton(onPressed: _load, child: const Text('Try again')),
                          ],
                        ),
                ),
              )
            else if (posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_on, size: 56, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(widget.emptyText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xs),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '$_total POST${_total == 1 ? '' : 'S'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
                  ),
                ),
              ),
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                itemCount: posts.length,
                itemBuilder: (_, index) => _PostTile(post: posts[index], onTap: () => _open(posts[index])),
              ),
              SliverToBoxAdapter(
                child: _loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : const SizedBox(height: AppSpacing.lg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _PostTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String label = switch (post.type) {
      PostType.text => 'Text post',
      PostType.image => 'Photo',
      PostType.video => 'Video',
    };
    final still = post.type == PostType.video ? post.thumbnailPath : post.mediaPath;
    return Semantics(
      button: true,
      label: '$label, ${post.commentCount} comments',
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post.type == PostType.text)
              Container(
                color: AppColors.cardBackground,
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                child: Text(
                  post.text ?? '',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              )
            else if (still != null)
              PostNetworkImage(url: still, cacheWidth: 400)
            else
              const ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.videocam, color: AppColors.textSecondary))),
            if (post.type == PostType.video)
              const Positioned(top: 6, right: 6, child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20)),
            if (post.commentCount > 0)
              Positioned(
                left: 6,
                bottom: 6,
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment, color: Colors.white, size: 13, shadows: [Shadow(blurRadius: 4)]),
                    const SizedBox(width: 3),
                    Text(
                      '${post.commentCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 4)]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
