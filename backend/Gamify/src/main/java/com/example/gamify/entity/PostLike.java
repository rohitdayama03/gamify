package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/** A player liking a post; at most one per player and post. */
@Entity
@Table(name = "post_likes",
        uniqueConstraints = @UniqueConstraint(name = "uk_post_like", columnNames = {"post_id", "player_id"}),
        indexes = @Index(name = "idx_post_like_player", columnList = "player_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PostLike {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "player_id", referencedColumnName = "player_id", nullable = false)
    private Player player;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
