package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * An invite from one player to another. Once ACCEPTED both players are friends.
 * A DECLINED row is kept forever so the sender can never invite the same player again.
 */
@Entity
@Table(name = "player_connections",
        uniqueConstraints = @UniqueConstraint(name = "uk_connection_sender_receiver", columnNames = {"sender_id", "receiver_id"}),
        indexes = {
                @Index(name = "idx_connection_sender", columnList = "sender_id"),
                @Index(name = "idx_connection_receiver", columnList = "receiver_id")
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlayerConnection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", referencedColumnName = "player_id", nullable = false)
    private Player sender;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "receiver_id", referencedColumnName = "player_id", nullable = false)
    private Player receiver;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private ConnectionStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "responded_at")
    private OffsetDateTime respondedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
