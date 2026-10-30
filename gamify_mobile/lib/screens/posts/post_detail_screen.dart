import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../models/connection_model.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../widgets/post_view.dart';
import '../player/player_profile_screen.dart';
import '../../widgets/player_avatar.dart';

/// One post with its likes and comments. Anyone can like, comment or reply; the author can delete the post and any
/// comment on it, and commenters can delete their own.
class PostDetailScreen extends StatefulWidget {
  final int postId;
  // Shown straight away when opened from a grid, then refreshed
  final Post? initial;

  const PostDetailScreen({super.key, required this.postId, this.initial});

  /// Resolves to true if the player deleted the post.
  static Future<bool?> open(BuildContext context, Post post) => Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id, initial: post)),
      );

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  final _scrollController = ScrollController();

  late Post? _post = widget.initial;
  String? _loadError;
  List<PostComment> _comments = [];
  bool _loadingComments = true;
  bool _hasMoreComments = false;
  bool _loadingMore = false;
  bool _sending = false;
  bool _liking = false;
  // The top-level comment a reply goes under, and who is being answered
  PostComment? _replyThread;
  String? _replyToName;
  // Comment ids being deleted
  final Set<int> _deleting = {};

  PostProvider get _provider => Provider.of<PostProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _commentController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([_provider.fetchPost(widget.postId), _provider.fetchComments(widget.postId)]);
    if (!mounted) return;
    final post = results[0] as Post?;
    final comments = results[1] as List<PostComment>?;
    setState(() {
      if (post != null) _post = post;
      _loadError = post == null ? _provider.errorMessage : null;
      _loadingComments = false;
      if (comments != null) {
        _comments = comments;
        _hasMoreComments = comments.length >= PostProvider.commentsPageSize;
      }
    });
  }

  Future<void> _loadMoreComments() async {
    if (_loadingMore || !_hasMoreComments || _comments.isEmpty) return;
    setState(() => _loadingMore = true);
    final more = await _provider.fetchComments(widget.postId, afterId: _comments.last.id);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (more != null) {
        final known = _comments.map((c) => c.id).toSet();
        _comments = [..._comments, ...more.where((c) => !known.contains(c.id))];
        _hasMoreComments = more.length >= PostProvider.commentsPageSize;
      }
    });
  }

  Future<void> _setLiked(bool liked) async {
    final before = _post;
    if (before == null || _liking || before.likedByMe == liked) return;
    // Show the like straight away, and put it back if the backend says no
    setState(() {
      _liking = true;
      _post = before.copyWith(likedByMe: liked, likeCount: (before.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30));
    });
    final result = await _provider.setLiked(before.id, liked);
    if (!mounted) return;
    setState(() {
      _liking = false;
      _post = result == null
          ? _post?.copyWith(likedByMe: before.likedByMe, likeCount: before.likeCount)
          : _post?.copyWith(likedByMe: result.liked, likeCount: result.likeCount);
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_provider.errorMessage ?? 'Could not like the post')));
    }
  }

  void _startReply(PostComment thread, PostComment target) {
    setState(() {
      _replyThread = thread;
      _replyToName = target.author.username;
    });
    // Mention the person answered when replying inside a thread, like Instagram
    if (target.id != thread.id && !_commentController.text.startsWith('@${target.author.username}')) {
      _commentController.text = '@${target.author.username} ${_commentController.text}';
      _commentController.selection = TextSelection.collapsed(offset: _commentController.text.length);
    }
    _commentFocus.requestFocus();
  }

  void _cancelReply() => setState(() {
        _replyThread = null;
        _replyToName = null;
      });

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final thread = _replyThread;
    final comment = await _provider.addComment(widget.postId, text, parentId: thread?.id);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (comment == null) return;
      _commentController.clear();
      _post = _post?.copyWith(commentCount: (_post?.commentCount ?? 0) + 1);
      if (thread == null) {
        _comments = [..._comments, comment];
      } else {
        _comments = [
          for (final c in _comments) c.id == thread.id ? c.withReplies([...c.replies, comment]) : c,
        ];
      }
      _replyThread = null;
      _replyToName = null;
    });
    if (comment == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_provider.errorMessage ?? 'Comment not posted')));
    } else if (thread == null && _scrollController.hasClients) {
      // New top-level comments go to the end of the list
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    final confirmed = await _confirm(
      title: 'Delete comment?',
      message: comment.parentId == null && comment.replies.isNotEmpty
          ? 'Its ${comment.replies.length} repl${comment.replies.length == 1 ? 'y' : 'ies'} will be deleted too.'
          : 'This can\'t be undone.',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting.add(comment.id));
    final ok = await _provider.deleteComment(comment.id);
    if (!mounted) return;
    setState(() {
      _deleting.remove(comment.id);
      if (!ok) return;
      final removed = comment.parentId == null ? 1 + comment.replies.length : 1;
      _post = _post?.copyWith(commentCount: ((_post?.commentCount ?? 0) - removed).clamp(0, 1 << 30));
      _comments = comment.parentId == null
          ? _comments.where((c) => c.id != comment.id).toList()
          : [
              for (final c in _comments)
                c.id == comment.parentId ? c.withReplies(c.replies.where((r) => r.id != comment.id).toList()) : c,
            ];
      if (_replyThread?.id == comment.id) {
        _replyThread = null;
        _replyToName = null;
      }
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_provider.errorMessage ?? 'Could not delete the comment')));
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await _confirm(title: 'Delete post?', message: 'The post and its comments will be removed.', action: 'Delete');
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await _provider.deletePost(widget.postId);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(ok ? 'Post deleted' : _provider.errorMessage ?? 'Could not delete the post')));
    if (ok) navigator.pop(true);
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (post != null && post.mine)
            PopupMenuButton<String>(
              onSelected: (_) => _deletePost(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete post', style: TextStyle(color: AppColors.error))),
              ],
            ),
        ],
      ),
      body: post == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                    ),
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) _loadMoreComments();
                        return false;
                      },
                      child: ListView(
                        controller: _scrollController,
                        children: [
                          PostView(
                            post: post,
                            onToggleLike: () => _setLiked(!post.likedByMe),
                            // Double-tap only ever likes, like Instagram
                            onDoubleTapLike: () => _setLiked(true),
                            onComment: () {
                              _cancelReply();
                              _commentFocus.requestFocus();
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          ..._buildComments(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  List<Widget> _buildComments() {
    if (_loadingComments) {
      return const [Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))];
    }
    if (_comments.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Text('No comments yet. Start the conversation.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        ),
      ];
    }
    return [
      for (final thread in _comments) ...[
        _CommentTile(
          comment: thread,
          deleting: _deleting.contains(thread.id),
          onReply: () => _startReply(thread, thread),
          onDelete: () => _deleteComment(thread),
        ),
        for (final reply in thread.replies)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: _CommentTile(
              comment: reply,
              small: true,
              deleting: _deleting.contains(reply.id),
              onReply: () => _startReply(thread, reply),
              onDelete: () => _deleteComment(reply),
            ),
          ),
      ],
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  Widget _buildInputBar() {
    final canSend = _commentController.text.trim().isNotEmpty && !_sending;
    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.cardBackground,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Replying to $_replyToName', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      visualDensity: VisualDensity.compact,
                      onPressed: _cancelReply,
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocus,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: PostLimits.maxCommentLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _replyToName == null ? 'Add a comment…' : 'Write a reply…',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Post comment',
                    onPressed: canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.send, color: canSend ? AppColors.primary : AppColors.textSecondary),
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

class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final bool small;
  final bool deleting;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    this.small = false,
    required this.deleting,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    return Opacity(
      opacity: deleting ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OpenProfileOnTap(
              playerId: author.playerId,
              username: author.username,
              child: _avatar(author, small ? 13 : 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${author.username}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: comment.content),
                  ])),
                  Row(
                    children: [
                      Text(timeAgo(comment.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      TextButton(
                        onPressed: deleting ? null : onReply,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Reply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (comment.canDelete)
              IconButton(
                tooltip: 'Delete comment',
                visualDensity: VisualDensity.compact,
                onPressed: deleting ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _avatar(PlayerSummary player, double radius) => PlayerAvatar(
      name: player.username,
      url: player.avatarUrl,
      radius: radius,
      textStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: radius * 0.9),
    );
