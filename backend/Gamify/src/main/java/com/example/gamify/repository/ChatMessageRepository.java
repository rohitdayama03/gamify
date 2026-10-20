package com.example.gamify.repository;

import com.example.gamify.entity.ChatMessage;
import com.example.gamify.entity.Player;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    String BETWEEN = "((m.sender = :a AND m.receiver = :b) OR (m.sender = :b AND m.receiver = :a))";

    // Newest first; the caller reverses. Used for the initial load and for "load older" (beforeId)
    @Query("SELECT m FROM ChatMessage m WHERE " + BETWEEN + " AND m.id < :beforeId ORDER BY m.id DESC")
    List<ChatMessage> findOlder(@Param("a") Player a, @Param("b") Player b, @Param("beforeId") Long beforeId, Pageable pageable);

    // Oldest first. Used when polling for messages that arrived after the last one the client has
    @Query("SELECT m FROM ChatMessage m WHERE " + BETWEEN + " AND m.id > :afterId ORDER BY m.id ASC")
    List<ChatMessage> findNewer(@Param("a") Player a, @Param("b") Player b, @Param("afterId") Long afterId, Pageable pageable);

    // Id of the latest message in each conversation the player is part of
    @Query("""
            SELECT MAX(m.id) FROM ChatMessage m
            WHERE m.sender = :player OR m.receiver = :player
            GROUP BY CASE WHEN m.sender = :player THEN m.receiver.playerId ELSE m.sender.playerId END
            """)
    List<Long> findLastMessageIds(@Param("player") Player player);

    @Query("SELECT m FROM ChatMessage m JOIN FETCH m.sender JOIN FETCH m.receiver WHERE m.id IN :ids ORDER BY m.id DESC")
    List<ChatMessage> findAllWithPlayersByIdIn(@Param("ids") List<Long> ids);

    // Rows of [senderId, unreadCount] for messages the player has not read yet
    @Query("SELECT m.sender.playerId, COUNT(m) FROM ChatMessage m WHERE m.receiver = :player AND m.readAt IS NULL GROUP BY m.sender.playerId")
    List<Object[]> countUnreadBySender(@Param("player") Player player);

    @Modifying
    @Query("UPDATE ChatMessage m SET m.readAt = :now WHERE m.receiver = :reader AND m.sender = :sender AND m.readAt IS NULL")
    void markAsRead(@Param("reader") Player reader, @Param("sender") Player sender, @Param("now") OffsetDateTime now);

    @Modifying
    @Query("DELETE FROM ChatMessage m WHERE m.sender = :player OR m.receiver = :player")
    void deleteAllInvolving(@Param("player") Player player);
}
