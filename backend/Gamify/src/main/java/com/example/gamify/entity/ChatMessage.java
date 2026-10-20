package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * A text message between two friends. {@code readAt} stays null until the receiver opens the chat.
 */
@Entity
@Table(name = "chat_messages", indexes = {
        @Index(name = "idx_chat_sender_receiver", columnList = "sender_id, receiver_id"),
        @Index(name = "idx_chat_receiver_unread", columnList = "receiver_id, read_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", referencedColumnName = "player_id", nullable = false)
    private Player sender;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "receiver_id", referencedColumnName = "player_id", nullable = false)
    private Player receiver;

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "read_at")
    private OffsetDateTime readAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
