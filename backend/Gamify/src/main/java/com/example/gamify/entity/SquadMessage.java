package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/** A text message sent to everyone who has joined a squad. */
@Entity
@Table(name = "squad_messages", indexes = @Index(name = "idx_squad_message_squad", columnList = "squad_id, id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SquadMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "squad_id", nullable = false)
    private Squad squad;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", referencedColumnName = "player_id", nullable = false)
    private Player sender;

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
