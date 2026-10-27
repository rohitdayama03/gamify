package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

// A headline pulled from a gaming news feed; the article itself stays on the publisher's site
@Entity
@Table(name = "news_items", indexes = {
        @Index(name = "idx_news_published_at", columnList = "published_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NewsItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Article URL; also identifies the item so repeated pulls don't duplicate it
    @Column(name = "link", nullable = false, unique = true, length = 1000)
    private String link;

    @Column(name = "title", nullable = false, length = 500)
    private String title;

    // Short teaser from the feed, as plain text
    @Column(name = "summary", columnDefinition = "TEXT")
    private String summary;

    @Column(name = "image_url", length = 1000)
    private String imageUrl;

    // The link is a video (e.g. YouTube) rather than an article; null on rows stored before videos existed
    @Column(name = "video")
    private Boolean video;

    // Publisher's topic, e.g. "Grand Theft Auto VI"
    @Column(name = "category", length = 200)
    private String category;

    @Column(name = "author", length = 200)
    private String author;

    @Column(name = "source", nullable = false, length = 100)
    private String source;

    // Set when the story is about one of the games GAMIFY supports
    @Enumerated(EnumType.STRING)
    @Column(name = "game", length = 20)
    private Game game;

    @Column(name = "published_at", nullable = false)
    private OffsetDateTime publishedAt;

    // Every story from one pull shares this, so the newest pull shows first
    @Column(name = "fetched_at", nullable = false)
    private OffsetDateTime fetchedAt;

    // Random position within its pull, so sources are mixed but the order is stable while scrolling
    @Column(name = "shuffle_key")
    private Integer shuffleKey;
}
