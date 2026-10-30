package com.example.gamify.dto;

import com.example.gamify.entity.PostType;

import java.time.OffsetDateTime;

/**
 * {@code mediaUrl} and {@code thumbnailUrl} are signed S3 links valid for a limited time; fetch them without
 * the login token. {@code mine} is true for the author; {@code likedByMe} is true when the viewer likes it.
 * {@code engagementScore} is 3 per comment (replies included) plus 1 per like; {@code score} is how the feed
 * ranks the post (see {@link com.example.gamify.feed.PostScore}), as of when it was fetched.
 */
public record PostResponse(
        Long id,
        PlayerSummaryResponse author,
        PostType type,
        String text,
        String mediaUrl,
        String thumbnailUrl,
        Integer mediaWidth,
        Integer mediaHeight,
        long likeCount,
        boolean likedByMe,
        long commentCount,
        long engagementScore,
        double score,
        boolean mine,
        OffsetDateTime createdAt
) {}
