package com.example.gamify.mapper;

import com.example.gamify.dto.PostResponse;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.Post;
import com.example.gamify.feed.PostScore;
import com.example.gamify.media.MediaStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;

@Component
@RequiredArgsConstructor
public class PostMapper {

    private final MediaStorage mediaStorage;
    private final ConnectionMapper connectionMapper;

    /** With the post's score now. */
    public PostResponse toResponse(Post post, Player viewer, boolean likedByViewer) {
        return toResponse(post, viewer, likedByViewer,
                PostScore.at(post.getCreatedAt(), post.getLikeCount(), post.getCommentCount(), OffsetDateTime.now()));
    }

    /** With a score worked out elsewhere, e.g. the one the feed ranked it by. */
    public PostResponse toResponse(Post post, Player viewer, boolean likedByViewer, double score) {
        return new PostResponse(
                post.getId(),
                connectionMapper.toPlayerSummary(post.getAuthor()),
                post.getType(),
                post.getText(),
                mediaStorage.url(post.getMediaKey()),
                mediaStorage.url(post.getThumbnailKey()),
                post.getMediaWidth(),
                post.getMediaHeight(),
                post.getLikeCount(),
                likedByViewer,
                post.getCommentCount(),
                PostScore.engagement(post.getLikeCount(), post.getCommentCount()),
                score,
                post.getAuthor().getPlayerId().equals(viewer.getPlayerId()),
                post.getCreatedAt()
        );
    }
}
