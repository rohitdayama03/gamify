package com.example.gamify.dto;

/** One feed entry: a post or a news item, whichever {@code type} says; the other is null. */
public record FeedItemResponse(Type type, PostResponse post, NewsItemResponse news) {

    public enum Type { POST, NEWS }

    public static FeedItemResponse of(PostResponse post) {
        return new FeedItemResponse(Type.POST, post, null);
    }

    public static FeedItemResponse of(NewsItemResponse news) {
        return new FeedItemResponse(Type.NEWS, null, news);
    }
}
