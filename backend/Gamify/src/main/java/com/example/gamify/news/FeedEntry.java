package com.example.gamify.news;

import java.time.OffsetDateTime;

/**
 * One item read from an RSS feed, before it is stored.
 *
 * @param publisher the original publisher when the feed aggregates others (Google News), or the
 *                  channel for a video feed (YouTube); otherwise null
 * @param video     whether the link is a video rather than an article
 */
public record FeedEntry(
        String link,
        String title,
        String summary,
        String imageUrl,
        String category,
        String author,
        String publisher,
        OffsetDateTime publishedAt,
        boolean video
) {}
