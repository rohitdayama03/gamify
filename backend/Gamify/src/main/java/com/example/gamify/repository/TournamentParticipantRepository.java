package com.example.gamify.repository;

import com.example.gamify.entity.ParticipantStatus;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.Tournament;
import com.example.gamify.entity.TournamentParticipant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface TournamentParticipantRepository extends JpaRepository<TournamentParticipant, Long> {

    Optional<TournamentParticipant> findByTournamentAndPlayer(Tournament tournament, Player player);

    // Winners first, then the rest in the order they asked to join
    @Query("""
            SELECT p FROM TournamentParticipant p JOIN FETCH p.player
            WHERE p.tournament = :tournament
            ORDER BY CASE WHEN p.placement IS NULL THEN 1 ELSE 0 END, p.placement ASC, p.createdAt ASC
            """)
    List<TournamentParticipant> findAllByTournament(@Param("tournament") Tournament tournament);

    long countByTournamentAndStatus(Tournament tournament, ParticipantStatus status);

    // Rows of [tournamentId, acceptedCount]
    @Query("""
            SELECT p.tournament.id, COUNT(p) FROM TournamentParticipant p
            WHERE p.tournament.id IN :ids AND p.status = com.example.gamify.entity.ParticipantStatus.ACCEPTED
            GROUP BY p.tournament.id
            """)
    List<Object[]> countAcceptedByTournamentIds(@Param("ids") Collection<Long> ids);

    @Query("SELECT p FROM TournamentParticipant p WHERE p.player = :player AND p.tournament.id IN :ids")
    List<TournamentParticipant> findMine(@Param("player") Player player, @Param("ids") Collection<Long> ids);

    // Pending requests to every tournament the player organizes, newest first
    @Query("""
            SELECT p FROM TournamentParticipant p JOIN FETCH p.player JOIN FETCH p.tournament t
            WHERE t.organizer = :organizer AND p.status = com.example.gamify.entity.ParticipantStatus.PENDING
            AND t.status = com.example.gamify.entity.TournamentStatus.OPEN
            ORDER BY p.createdAt DESC
            """)
    List<TournamentParticipant> findPendingForOrganizer(@Param("organizer") Player organizer);

    // Tournaments the player was accepted into, for their profile
    @Query("""
            SELECT p FROM TournamentParticipant p JOIN FETCH p.tournament t JOIN FETCH t.organizer
            WHERE p.player = :player AND p.status = com.example.gamify.entity.ParticipantStatus.ACCEPTED
            ORDER BY t.startsAt DESC
            """)
    List<TournamentParticipant> findAcceptedByPlayer(@Param("player") Player player);

    @Query("SELECT p.player.playerId FROM TournamentParticipant p WHERE p.tournament = :tournament AND p.status = com.example.gamify.entity.ParticipantStatus.ACCEPTED")
    List<Long> findAcceptedPlayerIds(@Param("tournament") Tournament tournament);

    @Modifying
    @Query("DELETE FROM TournamentParticipant p WHERE p.player = :player")
    void deleteAllByPlayer(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM TournamentParticipant p WHERE p.tournament = :tournament")
    void deleteAllByTournament(@Param("tournament") Tournament tournament);
}
