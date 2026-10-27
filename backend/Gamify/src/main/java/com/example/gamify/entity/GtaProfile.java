package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "gta_profiles", indexes = {
        @Index(name = "idx_gta_platform", columnList = "platform")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GtaProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "player_id", referencedColumnName = "player_id", nullable = false, unique = true)
    private Player player;

    @Column(name = "character_name", nullable = false, length = 50)
    private String characterName;

    // "PlayStation" or "PC"; players only match within the same platform
    @Column(name = "platform", nullable = false, length = 20)
    private String platform;

    // Comma-separated, e.g. "Heist,Racing"
    @Column(name = "activities", length = 100)
    private String activities;

    // Self-reported GTA Online rank, 1-100 ("rank" alone is an SQL function name, hence the prefix)
    @Column(name = "gta_rank")
    private Integer rank;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
        this.updatedAt = this.createdAt;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = OffsetDateTime.now();
    }
}
