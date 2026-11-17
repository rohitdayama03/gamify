package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

/** One player's value for one stat in one match. */
@Entity
@Table(name = "tournament_match_stats",
        uniqueConstraints = @UniqueConstraint(name = "uk_tournament_match_stat", columnNames = {"match_id", "participant_id", "stat_id"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TournamentMatchStat {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "match_id", nullable = false)
    private TournamentMatch match;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "participant_id", nullable = false)
    private TournamentParticipant participant;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "stat_id", nullable = false)
    private TournamentStat stat;

    @Column(name = "stat_value", nullable = false)
    private double value;
}
