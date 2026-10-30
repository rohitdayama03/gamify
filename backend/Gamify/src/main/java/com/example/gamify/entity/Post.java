package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnDefault;

import java.time.OffsetDateTime;

/**
 * A player's post: text on its own, or one image or video with an optional caption in {@code text}.
 * The files themselves are in S3 ({@link com.example.gamify.media.MediaStorage}); this row keeps their object
 * keys, {@code mediaKey} and, for videos, a still {@code thumbnailKey} made on the phone.
 */
@Entity
@Table(name = "posts", indexes = @Index(name = "idx_post_author", columnList = "author_id, id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Post {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "author_id", referencedColumnName = "player_id", nullable = false)
    private Player author;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 10)
    private PostType type;

    @Column(name = "text", columnDefinition = "TEXT")
    private String text;

    @Column(name = "media_key", length = 64)
    private String mediaKey;

    @Column(name = "thumbnail_key", length = 64)
    private String thumbnailKey;

    // Pixel size as the phone reported it, so the app can reserve space before the media loads
    @Column(name = "media_width")
    private Integer mediaWidth;

    @Column(name = "media_height")
    private Integer mediaHeight;

    @Column(name = "media_size_bytes")
    private Long mediaSizeBytes;

    // Kept in step with post_likes and post_comments (replies included), so the feed can rank posts
    // without counting rows; PostCounters recounts them at startup
    @Builder.Default
    @ColumnDefault("0")
    @Column(name = "like_count", nullable = false)
    private int likeCount = 0;

    @Builder.Default
    @ColumnDefault("0")
    @Column(name = "comment_count", nullable = false)
    private int commentCount = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
