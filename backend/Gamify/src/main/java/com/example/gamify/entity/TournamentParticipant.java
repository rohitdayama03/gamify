package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * A player's request to join a tournament. A REJECTED row is kept so the player can't ask again;
 * withdrawing deletes the row. {@code placement} (1 = winner) is set when the result is recorded, and
 * {@code lastReadMessageId} tracks the organizer's announcements the player has seen.
 * <p>
 * In a tournament with a format, {@code slotNo} is the player's position in the draw. If the player deletes
 * their account after the tournament started, the row stays so the fixtures still add up: {@code player}
 * becomes null and {@code formerUsername} keeps the name they played under.
 */
@Entity
@Table(name = "tournament_participants",
        uniqueConstraints = @UniqueConstraint(name = "uk_tournament_participant", columnNames = {"tournament_id", "player_id"}),
        indexes = @Index(name = "idx_tournament_participant_player", columnList = "player_id, status"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TournamentParticipant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "player_id", referencedColumnName = "player_id")
    private Player player;

    @Column(name = "former_username", length = 50)
    private String formerUsername;

    @Column(name = "slot_no")
    private Integer slotNo;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private ParticipantStatus status;

    @Column(name = "placement")
    private Integer placement;

    @Column(name = "last_read_message_id")
    private Long lastReadMessageId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "responded_at")
    private OffsetDateTime respondedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
