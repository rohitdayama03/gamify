package com.example.gamify.dto;

import java.util.List;

/** A page of the feed; pass {@code nextCursor} back for the next one. It's null at the end. */
public record FeedPageResponse(List<FeedItemResponse> items, String nextCursor) {}
