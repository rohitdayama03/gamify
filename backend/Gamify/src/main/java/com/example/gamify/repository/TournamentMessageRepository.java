package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.Tournament;
import com.example.gamify.entity.TournamentMessage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface TournamentMessageRepository extends JpaRepository<TournamentMessage, Long> {

    // Newest first; the caller reverses. Used for the initial load and for "load older" (beforeId)
    @Query("SELECT m FROM TournamentMessage m JOIN FETCH m.sender WHERE m.tournament = :tournament AND m.id < :beforeId ORDER BY m.id DESC")
    List<TournamentMessage> findOlder(@Param("tournament") Tournament tournament, @Param("beforeId") Long beforeId, Pageable pageable);

    // Oldest first. Used when polling for messages that arrived after the last one the client has
    @Query("SELECT m FROM TournamentMessage m JOIN FETCH m.sender WHERE m.tournament = :tournament AND m.id > :afterId ORDER BY m.id ASC")
    List<TournamentMessage> findNewer(@Param("tournament") Tournament tournament, @Param("afterId") Long afterId, Pageable pageable);

    // The latest message in each of the given tournaments
    @Query("""
            SELECT m FROM TournamentMessage m JOIN FETCH m.sender
            WHERE m.id IN (SELECT MAX(m2.id) FROM TournamentMessage m2 WHERE m2.tournament.id IN :ids GROUP BY m2.tournament.id)
            """)
    List<TournamentMessage> findLastMessages(@Param("ids") Collection<Long> ids);

    @Query("SELECT COALESCE(MAX(m.id), 0) FROM TournamentMessage m WHERE m.tournament = :tournament")
    Long findLastMessageId(@Param("tournament") Tournament tournament);

    // Rows of [tournamentId, unreadCount] for tournaments the player was accepted into
    @Query("""
            SELECT p.tournament.id, COUNT(m) FROM TournamentParticipant p, TournamentMessage m
            WHERE p.player = :player
            AND p.status = com.example.gamify.entity.ParticipantStatus.ACCEPTED
            AND m.tournament = p.tournament
            AND m.id > COALESCE(p.lastReadMessageId, 0)
            GROUP BY p.tournament.id
            """)
    List<Object[]> countUnreadByTournament(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM TournamentMessage m WHERE m.tournament = :tournament")
    void deleteAllByTournament(@Param("tournament") Tournament tournament);
}
