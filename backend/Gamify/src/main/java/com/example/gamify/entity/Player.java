package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "players", indexes = {
        @Index(name = "idx_players_username", columnList = "username"),
        @Index(name = "idx_players_country_lang", columnList = "country, language")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Player {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "player_id")
    private Long playerId;

    @Column(name = "username", nullable = false, unique = true, length = 50)
    private String username;

    @Column(name = "password", nullable = false)
    private String password;

    @Column(name = "player_bio", columnDefinition = "TEXT")
    private String playerBio;

    @Column(name = "language", length = 30)
    private String language;

    @Column(name = "country", length = 50)
    private String country;

    @Column(name = "secret_question", nullable = false)
    private String secretQuestion;

    @Column(name = "secret_answer", nullable = false)
    private String secretAnswer;

    // One-to-One relationships with Game Profiles
    @OneToOne(mappedBy = "player", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private BgmiProfile bgmiProfile;

    @OneToOne(mappedBy = "player", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private EfootballProfile efootballProfile;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
        this.updatedAt = OffsetDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = OffsetDateTime.now();
    }
}