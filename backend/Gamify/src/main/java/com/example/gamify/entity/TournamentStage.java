package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * One step of a tournament's format, played in {@code seq} order. Stage 1 takes every player; each later
 * stage takes the players who went through from the one before. {@code finishedAt} is set when the organizer
 * finishes the stage, which locks its results.
 */
@Entity
@Table(name = "tournament_stages",
        uniqueConstraints = @UniqueConstraint(name = "uk_tournament_stage_seq", columnNames = {"tournament_id", "seq"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TournamentStage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    // 1 for the first stage
    @Column(name = "seq", nullable = false)
    private int seq;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 20)
    private StageType type;

    // Players who play in this stage
    @Column(name = "entrants", nullable = false)
    private int entrants;

    // League only: 1 for a plain league
    @Column(name = "group_count", nullable = false)
    private int groupCount;

    // League only: 1 = everyone plays once, 2 = home and away
    @Column(name = "rounds", nullable = false)
    private int rounds;

    // League only: players per group who go through to the next stage; 0 in the last stage
    @Column(name = "advance_per_group", nullable = false)
    private int advancePerGroup;

    // Knockout only
    @Column(name = "third_place", nullable = false)
    private boolean thirdPlace;

    @Column(name = "finished_at")
    private OffsetDateTime finishedAt;

    public boolean isFinished() {
        return finishedAt != null;
    }
}
