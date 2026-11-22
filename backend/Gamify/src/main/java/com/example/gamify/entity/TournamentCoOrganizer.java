package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * A player the tournament's creator added to help run it. Co-organizers can do everything the creator can
 * except cancel the tournament and add or remove organizers. The creator stays on {@link Tournament#getOrganizer()}.
 */
@Entity
@Table(name = "tournament_co_organizers",
        uniqueConstraints = @UniqueConstraint(name = "uk_tournament_co_organizer", columnNames = {"tournament_id", "player_id"}),
        indexes = @Index(name = "idx_tournament_co_organizer_player", columnList = "player_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TournamentCoOrganizer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "player_id", referencedColumnName = "player_id", nullable = false)
    private Player player;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
