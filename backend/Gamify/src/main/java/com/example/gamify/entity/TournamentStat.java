package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

/** A stat column the organizer chose for a tournament, e.g. "Shots". Values are entered with each result. */
@Entity
@Table(name = "tournament_stats")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TournamentStat {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @Column(name = "label", nullable = false, length = 20)
    private String label;

    @Enumerated(EnumType.STRING)
    @Column(name = "aggregation", nullable = false, length = 10)
    private StatAggregation aggregation;

    // Column order on the leaderboard
    @Column(name = "seq", nullable = false)
    private int seq;
}
