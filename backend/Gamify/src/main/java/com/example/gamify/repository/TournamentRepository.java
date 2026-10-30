package com.example.gamify.repository;

import com.example.gamify.entity.Game;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.Tournament;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TournamentRepository extends JpaRepository<Tournament, Long> {

    // Open tournaments, soonest first
    @Query("SELECT t FROM Tournament t JOIN FETCH t.organizer WHERE t.status = com.example.gamify.entity.TournamentStatus.OPEN ORDER BY t.startsAt ASC")
    List<Tournament> findOpen(Pageable pageable);

    @Query("SELECT t FROM Tournament t JOIN FETCH t.organizer WHERE t.status = com.example.gamify.entity.TournamentStatus.OPEN AND t.game = :game ORDER BY t.startsAt ASC")
    List<Tournament> findOpenByGame(@Param("game") Game game, Pageable pageable);

    // Tournaments the player organizes or has asked to join, latest start first
    @Query("""
            SELECT t FROM Tournament t JOIN FETCH t.organizer
            WHERE t.organizer = :player
            OR t.id IN (SELECT p.tournament.id FROM TournamentParticipant p WHERE p.player = :player)
            ORDER BY t.startsAt DESC
            """)
    List<Tournament> findInvolving(@Param("player") Player player);

    List<Tournament> findAllByOrganizer(Player organizer);
}
