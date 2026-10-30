package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.Squad;
import com.example.gamify.entity.SquadMessage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface SquadMessageRepository extends JpaRepository<SquadMessage, Long> {

    // Newest first; the caller reverses. Used for the initial load and for "load older" (beforeId)
    @Query("SELECT m FROM SquadMessage m JOIN FETCH m.sender WHERE m.squad = :squad AND m.id < :beforeId ORDER BY m.id DESC")
    List<SquadMessage> findOlder(@Param("squad") Squad squad, @Param("beforeId") Long beforeId, Pageable pageable);

    // Oldest first. Used when polling for messages that arrived after the last one the client has
    @Query("SELECT m FROM SquadMessage m JOIN FETCH m.sender WHERE m.squad = :squad AND m.id > :afterId ORDER BY m.id ASC")
    List<SquadMessage> findNewer(@Param("squad") Squad squad, @Param("afterId") Long afterId, Pageable pageable);

    // The latest message in each of the given squads
    @Query("""
            SELECT m FROM SquadMessage m JOIN FETCH m.sender
            WHERE m.id IN (SELECT MAX(m2.id) FROM SquadMessage m2 WHERE m2.squad.id IN :squadIds GROUP BY m2.squad.id)
            """)
    List<SquadMessage> findLastMessages(@Param("squadIds") Collection<Long> squadIds);

    @Query("SELECT COALESCE(MAX(m.id), 0) FROM SquadMessage m WHERE m.squad = :squad")
    Long findLastMessageId(@Param("squad") Squad squad);

    // Rows of [squadId, unreadCount]: messages from others newer than what the player last read
    @Query("""
            SELECT mem.squad.id, COUNT(msg) FROM SquadMember mem, SquadMessage msg
            WHERE mem.player = :player
            AND mem.status = com.example.gamify.entity.SquadMemberStatus.JOINED
            AND msg.squad = mem.squad
            AND msg.id > COALESCE(mem.lastReadMessageId, 0)
            AND msg.sender <> :player
            GROUP BY mem.squad.id
            """)
    List<Object[]> countUnreadBySquad(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM SquadMessage m WHERE m.sender = :player")
    void deleteAllBySender(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM SquadMessage m WHERE m.squad = :squad")
    void deleteAllBySquad(@Param("squad") Squad squad);
}
