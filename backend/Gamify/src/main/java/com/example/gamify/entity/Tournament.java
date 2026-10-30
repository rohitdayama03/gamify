package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * A competition for one game. Anyone can organize one; players request to join and the organizer
 * accepts or rejects them. Recording the result marks it COMPLETED.
 */
@Entity
@Table(name = "tournaments", indexes = {
        @Index(name = "idx_tournament_game_status", columnList = "game, status, starts_at"),
        @Index(name = "idx_tournament_organizer", columnList = "organizer_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Tournament {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name", nullable = false, length = 60)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "game", nullable = false, length = 20)
    private Game game;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "starts_at", nullable = false)
    private OffsetDateTime startsAt;

    // Null means no limit
    @Column(name = "max_participants")
    private Integer maxParticipants;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "organizer_id", referencedColumnName = "player_id", nullable = false)
    private Player organizer;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private TournamentStatus status;

    // Free text the organizer adds with the result, e.g. the final score
    @Column(name = "result_notes", columnDefinition = "TEXT")
    private String resultNotes;

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
