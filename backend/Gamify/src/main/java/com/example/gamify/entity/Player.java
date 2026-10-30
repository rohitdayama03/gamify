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

    // Signs in with a code sent here on WhatsApp. Nullable since accounts made before OTP sign-in have none
    @Column(name = "phone_number", unique = true, length = 20)
    private String phoneNumber;

    @Column(name = "player_bio", columnDefinition = "TEXT")
    private String playerBio;

    // S3 object key of their profile picture; null shows their initial instead
    @Column(name = "avatar_key", length = 64)
    private String avatarKey;

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