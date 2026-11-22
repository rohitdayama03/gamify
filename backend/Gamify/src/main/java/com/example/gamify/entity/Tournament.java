package com.example.gamify.entity;

import com.example.gamify.tournament.Standings;
import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * A competition for one game. Anyone can organize one; players request to join and the organizer
 * accepts or rejects them.
 * <p>
 * A simple tournament ({@code slots} null) is settled by recording placements. A tournament with a format
 * ({@code slots} set, eFootball only) has stages and fixtures: the organizer starts it once all slots are
 * filled, enters each match result, and finishes stage by stage.
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

    // Players in a tournament with a format; null for a simple tournament
    @Column(name = "slots")
    private Integer slots;

    // League points for a win, draw and loss; null on tournaments from before they could be chosen
    @Column(name = "win_points")
    private Integer winPoints;

    @Column(name = "draw_points")
    private Integer drawPoints;

    @Column(name = "loss_points")
    private Integer lossPoints;

    @Column(name = "started_at")
    private OffsetDateTime startedAt;

    // Free text the organizer adds with the result, e.g. the final score
    @Column(name = "result_notes", columnDefinition = "TEXT")
    private String resultNotes;

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    public Standings.Points points() {
        return winPoints == null ? Standings.Points.LEGACY : new Standings.Points(winPoints, drawPoints, lossPoints);
    }

    public boolean hasFormat() {
        return slots != null;
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
