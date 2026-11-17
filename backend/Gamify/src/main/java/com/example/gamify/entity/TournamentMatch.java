package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * One fixture. The fixtures are generated from the format before anyone joins, so each side starts as a
 * placeholder ({@code homeSource}, e.g. "SLOT:3", "GROUP:2:1", "WINNER:1:2"; see
 * {@link com.example.gamify.tournament.Sources}) and the player is filled in at the draw, when the stage before
 * finishes, or when the knockout match feeding it has a result. {@code resultAt} is set once a result is in.
 */
@Entity
@Table(name = "tournament_matches", indexes = @Index(name = "idx_tournament_match_stage", columnList = "stage_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TournamentMatch {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "stage_id", nullable = false)
    private TournamentStage stage;

    // League only, from 1
    @Column(name = "group_no")
    private Integer groupNo;

    @Column(name = "round_no", nullable = false)
    private int roundNo;

    // Position within the round (and group); in a knockout's last round, 2 is the third-place match
    @Column(name = "match_no", nullable = false)
    private int matchNo;

    @Column(name = "home_source", nullable = false, length = 20)
    private String homeSource;

    @Column(name = "away_source", nullable = false, length = 20)
    private String awaySource;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "home_participant_id")
    private TournamentParticipant home;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "away_participant_id")
    private TournamentParticipant away;

    @Column(name = "home_score")
    private Integer homeScore;

    @Column(name = "away_score")
    private Integer awayScore;

    // Knockout only, when the score is level
    @Column(name = "home_pens")
    private Integer homePens;

    @Column(name = "away_pens")
    private Integer awayPens;

    // Null for a league draw
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "winner_participant_id")
    private TournamentParticipant winner;

    @Column(name = "result_at")
    private OffsetDateTime resultAt;

    public boolean hasResult() {
        return resultAt != null;
    }

    public boolean isReady() {
        return home != null && away != null;
    }
}
