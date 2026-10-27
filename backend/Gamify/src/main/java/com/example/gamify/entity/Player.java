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

    // Nullable at the DB level so accounts created before email was required still load
    @Column(name = "email", unique = true, length = 255)
    private String email;

    @Column(name = "password", nullable = false)
    private String password;

    @Column(name = "player_bio", columnDefinition = "TEXT")
    private String playerBio;

    // Comma-separated list, e.g. "English, Hindi"
    @Column(name = "language", length = 255)
    private String language;

    @Column(name = "country", length = 50)
    private String country;

    // Comma-separated Game names chosen during onboarding, e.g. "GTA,BGMI"
    @Column(name = "interested_games", length = 50)
    private String interestedGames;

    // Game the player last browsed, so returning users land on it
    @Enumerated(EnumType.STRING)
    @Column(name = "last_game", length = 20)
    private Game lastGame;

    @Column(name = "secret_question", nullable = false)
    private String secretQuestion;

    @Column(name = "secret_answer", nullable = false)
    private String secretAnswer;

    // One-to-One relationships with Game Profiles
    @OneToOne(mappedBy = "player", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private GtaProfile gtaProfile;

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