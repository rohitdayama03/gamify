package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.Post;
import com.example.gamify.entity.PostComment;
import com.example.gamify.entity.PostType;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.ConnectionMapper;
import com.example.gamify.mapper.PostMapper;
import com.example.gamify.media.MediaStorage;
import com.example.gamify.media.MediaUploadService;
import com.example.gamify.media.UploadKind;
import com.example.gamify.notification.PushNotification;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.repository.PostCommentRepository;
import com.example.gamify.repository.PostLikeRepository;
import com.example.gamify.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PostServiceImpl implements PostService {

    // Fills a 3-column profile grid evenly
    private static final int POSTS_PAGE_SIZE = 18;

    private static final int COMMENTS_PAGE_SIZE = 30;

    // Longest comment text shown in a notification
    private static final int PREVIEW_LENGTH = 100;

    private static final int MAX_DIMENSION = 10_000;

    private final PlayerRepository playerRepository;
    private final PostRepository postRepository;
    private final PostCommentRepository commentRepository;
    private final PostLikeRepository likeRepository;
    private final MediaStorage mediaStorage;
    private final MediaUploadService uploadService;
    private final ConnectionMapper connectionMapper;
    private final PostMapper postMapper;
    private final ApplicationEventPublisher events;

    @Override
    @Transactional
    public UploadSessionResponse startUpload(String username, CreateUploadsRequest request) {
        return uploadService.startSession(findPlayer(username), request);
    }

    @Override
    @Transactional
    public void cancelUpload(String username) {
        uploadService.cancelSession(findPlayer(username));
    }

    @Override
    @Transactional
    public PostResponse createPost(String username, CreatePostRequest request) {
        Player me = findPlayer(username);
        PostType type = request.type();
        String text = request.text() == null ? null : request.text().trim();
        if (text != null && text.isEmpty()) {
            text = null;
        }

        // One post at a time: waits for any other commit by this player, and a text post can't jump a media upload
        uploadService.beginCommit(me, request.mediaKey() != null || request.thumbnailKey() != null);

        Post.PostBuilder post = Post.builder().author(me).type(type).text(text);
        if (type == PostType.TEXT) {
            if (text == null) {
                throw new BadRequestException("Write something to post");
            }
            if (request.mediaKey() != null || request.thumbnailKey() != null) {
                throw new BadRequestException("Text posts can't have a file");
            }
        } else {
            if (request.mediaKey() == null) {
                throw new BadRequestException("Upload " + (type == PostType.IMAGE ? "an image" : "a video") + " first");
            }
            boolean video = type == PostType.VIDEO;
            MediaUploadService.ClaimedUpload media = uploadService.claim(me, request.mediaKey(), video ? UploadKind.VIDEO : UploadKind.IMAGE);
            post.mediaKey(media.key())
                    .mediaSizeBytes(media.size())
                    .mediaWidth(dimension(request.width()))
                    .mediaHeight(dimension(request.height()));
            if (request.thumbnailKey() != null) {
                if (!video) {
                    throw new BadRequestException("Only videos have a thumbnail");
                }
                post.thumbnailKey(uploadService.claim(me, request.thumbnailKey(), UploadKind.THUMBNAIL).key());
            }
            uploadService.endSession(me);
        }
        return postMapper.toResponse(postRepository.save(post.build()), me, false);
    }

    @Override
    @Transactional(readOnly = true)
    public PostResponse getPost(String username, Long postId) {
        Player me = findPlayer(username);
        Post post = findPost(postId);
        return postMapper.toResponse(post, me, likeRepository.existsByPostAndPlayer(post, me));
    }

    @Override
    @Transactional(readOnly = true)
    public PlayerPostsResponse getPlayerPosts(String username, Long playerId, Long beforeId) {
        Player me = findPlayer(username);
        Player author = playerRepository.findById(playerId)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with ID: " + playerId));
        List<Post> posts = postRepository.findByAuthorBefore(
                author, beforeId != null ? beforeId : Long.MAX_VALUE, PageRequest.of(0, POSTS_PAGE_SIZE));
        Set<Long> liked = posts.isEmpty() ? Set.of()
                : new HashSet<>(likeRepository.findLikedPostIds(me, posts.stream().map(Post::getId).toList()));
        return new PlayerPostsResponse(
                postRepository.countByAuthor(author),
                posts.stream().map(p -> postMapper.toResponse(p, me, liked.contains(p.getId()))).toList()
        );
    }

    @Override
    @Transactional
    public void deletePost(String username, Long postId) {
        Player me = findPlayer(username);
        Post post = findPost(postId);
        if (!isAuthor(post, me)) {
            throw new BadRequestException("You can only delete your own posts");
        }
        delete(post);
    }

    @Override
    @Transactional
    public LikeResponse likePost(String username, Long postId) {
        Player me = findPlayer(username);
        Post post = findPost(postId);
        boolean added = likeRepository.insertIfAbsent(post.getId(), me.getPlayerId()) == 1;
        if (added) {
            postRepository.addLikes(post.getId(), 1);
        }
        Long authorId = post.getAuthor().getPlayerId();
        // Only a new like is news; the tag keeps a like, unlike, like from stacking up on the author's phone
        if (added && !authorId.equals(me.getPlayerId())) {
            events.publishEvent(new PushNotification(
                    authorId,
                    me.getUsername() + " liked your post",
                    post.getText() == null ? "" : preview(post.getText()),
                    PushNotification.CHANNEL_ACTIVITY,
                    "post-like-" + post.getId() + "-" + me.getPlayerId(),
                    Map.of("type", "post_like", "postId", String.valueOf(post.getId()))
            ));
        }
        return new LikeResponse(true, likeRepository.countByPost(post));
    }

    @Override
    @Transactional
    public LikeResponse unlikePost(String username, Long postId) {
        Player me = findPlayer(username);
        Post post = findPost(postId);
        if (likeRepository.deleteByPostAndPlayer(post, me) == 1) {
            postRepository.addLikes(post.getId(), -1);
        }
        return new LikeResponse(false, likeRepository.countByPost(post));
    }

    @Override
    @Transactional(readOnly = true)
    public List<CommentResponse> getComments(String username, Long postId, Long afterId) {
        Player me = findPlayer(username);
        Post post = findPost(postId);
        List<PostComment> topLevel = commentRepository.findTopLevel(
                post, afterId != null ? afterId : 0L, PageRequest.of(0, COMMENTS_PAGE_SIZE));
        if (topLevel.isEmpty()) {
            return List.of();
        }
        Map<Long, List<PostComment>> repliesByParent = commentRepository
                .findReplies(topLevel.stream().map(PostComment::getId).toList()).stream()
                .collect(Collectors.groupingBy(c -> c.getParent().getId(), LinkedHashMap::new, Collectors.toList()));
        return topLevel.stream()
                .map(c -> toCommentResponse(c, post, me, repliesByParent.getOrDefault(c.getId(), List.of())))
                .toList();
    }

    @Override
    @Transactional
    public CommentResponse addComment(String username, Long postId, String content, Long parentId) {
        Player me = findPlayer(username);
        Post post = findPost(postId);

        PostComment parent = null;
        if (parentId != null) {
            parent = commentRepository.findById(parentId)
                    .filter(c -> c.getPost().getId().equals(post.getId()))
                    .orElseThrow(() -> new ResourceNotFoundException("Comment not found with ID: " + parentId));
            // Replying to a reply joins the same thread
            if (parent.getParent() != null) {
                parent = parent.getParent();
            }
        }
        PostComment saved = commentRepository.save(PostComment.builder()
                .post(post)
                .author(me)
                .parent(parent)
                .content(content.trim())
                .build());
        postRepository.addComments(post.getId(), 1);

        Long postAuthorId = post.getAuthor().getPlayerId();
        Long replyToId = parentId == null ? null
                : commentRepository.findById(parentId).map(c -> c.getAuthor().getPlayerId()).orElse(null);
        // The person replied to hears about the reply; the post's author hears about every comment
        if (replyToId != null && !replyToId.equals(me.getPlayerId())) {
            notify(replyToId, me.getUsername() + " replied to your comment", content, post);
        }
        if (!postAuthorId.equals(me.getPlayerId()) && !postAuthorId.equals(replyToId)) {
            notify(postAuthorId, me.getUsername() + " commented on your post", content, post);
        }
        return toCommentResponse(saved, post, me, List.of());
    }

    // The comment's author or the post's author may delete it; a top-level comment takes its replies with it
    @Override
    @Transactional
    public void deleteComment(String username, Long commentId) {
        Player me = findPlayer(username);
        PostComment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new ResourceNotFoundException("Comment not found with ID: " + commentId));
        if (!canDelete(comment, comment.getPost(), me)) {
            throw new BadRequestException("You can't delete this comment");
        }
        int removed = 1;
        if (comment.getParent() == null) {
            removed += commentRepository.deleteReplies(comment);
        }
        commentRepository.delete(comment);
        postRepository.addComments(comment.getPost().getId(), -removed);
    }

    @Override
    @Transactional
    public void removePlayerContent(Player player) {
        for (Post post : postRepository.findAllByAuthor(player)) {
            delete(post);
        }
        // Other people's posts lose this player's likes and comments, and replies to their comments
        Set<Long> touched = new HashSet<>(likeRepository.findPostIdsLikedBy(player));
        touched.addAll(commentRepository.findPostIdsInvolving(player));
        commentRepository.deleteRepliesToAuthor(player);
        commentRepository.deleteRepliesByAuthor(player);
        commentRepository.deleteAllByAuthor(player);
        likeRepository.deleteAllByPlayer(player);
        if (!touched.isEmpty()) {
            postRepository.recount(touched);
        }
        uploadService.deleteAllFor(player);
    }

    private void delete(Post post) {
        commentRepository.deleteRepliesOnPost(post);
        commentRepository.deleteAllOnPost(post);
        likeRepository.deleteAllOnPost(post);
        postRepository.delete(post);
        // Only remove the files once the rows are really gone
        uploadService.deleteAfterCommit(Arrays.asList(post.getMediaKey(), post.getThumbnailKey()));
    }

    private void notify(Long recipientId, String title, String content, Post post) {
        events.publishEvent(new PushNotification(
                recipientId,
                title,
                preview(content.trim()),
                PushNotification.CHANNEL_ACTIVITY,
                "post-" + post.getId(),
                Map.of("type", "post_comment", "postId", String.valueOf(post.getId()))
        ));
    }

    private CommentResponse toCommentResponse(PostComment comment, Post post, Player me, List<PostComment> replies) {
        return new CommentResponse(
                comment.getId(),
                post.getId(),
                comment.getParent() == null ? null : comment.getParent().getId(),
                connectionMapper.toPlayerSummary(comment.getAuthor()),
                comment.getContent(),
                comment.getAuthor().getPlayerId().equals(me.getPlayerId()),
                canDelete(comment, post, me),
                comment.getCreatedAt(),
                replies.stream().map(r -> toCommentResponse(r, post, me, List.of())).toList()
        );
    }

    private static boolean canDelete(PostComment comment, Post post, Player me) {
        return comment.getAuthor().getPlayerId().equals(me.getPlayerId()) || isAuthor(post, me);
    }

    private static boolean isAuthor(Post post, Player player) {
        return post.getAuthor().getPlayerId().equals(player.getPlayerId());
    }

    private static Integer dimension(Integer value) {
        return value != null && value > 0 && value <= MAX_DIMENSION ? value : null;
    }

    private static String preview(String content) {
        return content.length() <= PREVIEW_LENGTH ? content : content.substring(0, PREVIEW_LENGTH) + "…";
    }

    private Post findPost(Long postId) {
        return postRepository.findWithAuthor(postId)
                .orElseThrow(() -> new ResourceNotFoundException("Post not found with ID: " + postId));
    }

    private Player findPlayer(String username) {
        return playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
    }
}
