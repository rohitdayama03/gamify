package com.example.gamify.dto;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * A comment. Top-level comments carry their {@code replies} (oldest first); replies have an empty list.
 * {@code canDelete} is true for the comment's author and for the post's author.
 */
public record CommentResponse(
        Long id,
        Long postId,
        Long parentId,
        PlayerSummaryResponse author,
        String content,
        boolean mine,
        boolean canDelete,
        OffsetDateTime createdAt,
        List<CommentResponse> replies
) {}
