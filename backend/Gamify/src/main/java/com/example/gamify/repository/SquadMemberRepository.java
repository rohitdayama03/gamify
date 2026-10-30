package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.Squad;
import com.example.gamify.entity.SquadMember;
import com.example.gamify.entity.SquadMemberStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface SquadMemberRepository extends JpaRepository<SquadMember, Long> {

    Optional<SquadMember> findBySquadAndPlayer(Squad squad, Player player);

    // The player's memberships with a given status, squad fetched to avoid N+1 queries
    @Query("""
            SELECT m FROM SquadMember m
            JOIN FETCH m.squad
            LEFT JOIN FETCH m.invitedBy
            WHERE m.player = :player AND m.status = :status
            ORDER BY m.createdAt DESC
            """)
    List<SquadMember> findAllByPlayerAndStatus(@Param("player") Player player, @Param("status") SquadMemberStatus status);

    // Joined members first in the order they joined, then pending invites
    @Query("""
            SELECT m FROM SquadMember m
            JOIN FETCH m.player
            WHERE m.squad = :squad
            ORDER BY m.status DESC, COALESCE(m.joinedAt, m.createdAt) ASC
            """)
    List<SquadMember> findAllBySquad(@Param("squad") Squad squad);

    @Query("SELECT m.player.playerId FROM SquadMember m WHERE m.squad = :squad AND m.status = com.example.gamify.entity.SquadMemberStatus.JOINED")
    List<Long> findJoinedPlayerIds(@Param("squad") Squad squad);

    // Rows of [squadId, joinedCount]
    @Query("""
            SELECT m.squad.id, COUNT(m) FROM SquadMember m
            WHERE m.squad.id IN :squadIds AND m.status = com.example.gamify.entity.SquadMemberStatus.JOINED
            GROUP BY m.squad.id
            """)
    List<Object[]> countJoinedBySquadIds(@Param("squadIds") Collection<Long> squadIds);

    // Joined and invited, to cap squad size
    long countBySquad(Squad squad);

    @Modifying
    @Query("UPDATE SquadMember m SET m.invitedBy = NULL WHERE m.invitedBy = :player")
    void clearInvitedBy(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM SquadMember m WHERE m.player = :player")
    void deleteAllByPlayer(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM SquadMember m WHERE m.squad = :squad")
    void deleteAllBySquad(@Param("squad") Squad squad);
}
