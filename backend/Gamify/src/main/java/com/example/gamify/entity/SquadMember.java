package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * A player's place in a squad: INVITED until they accept, then JOINED. Declining, leaving or being
 * removed deletes the row, so the player can be invited again later.
 * {@code lastReadMessageId} is the newest squad message the player has seen, for unread counts.
 */
@Entity
@Table(name = "squad_members",
        uniqueConstraints = @UniqueConstraint(name = "uk_squad_member", columnNames = {"squad_id", "player_id"}),
        indexes = @Index(name = "idx_squad_member_player", columnList = "player_id, status"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SquadMember {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "squad_id", nullable = false)
    private Squad squad;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "player_id", referencedColumnName = "player_id", nullable = false)
    private Player player;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private SquadMemberStatus status;

    // Null for the creator, and once the inviter deletes their account
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "invited_by_id", referencedColumnName = "player_id")
    private Player invitedBy;

    @Column(name = "last_read_message_id")
    private Long lastReadMessageId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "joined_at")
    private OffsetDateTime joinedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
