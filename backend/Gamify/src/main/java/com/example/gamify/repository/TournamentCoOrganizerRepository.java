package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.Tournament;
import com.example.gamify.entity.TournamentCoOrganizer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TournamentCoOrganizerRepository extends JpaRepository<TournamentCoOrganizer, Long> {

    boolean existsByTournamentAndPlayer(Tournament tournament, Player player);

    Optional<TournamentCoOrganizer> findByTournamentAndPlayer(Tournament tournament, Player player);

    long countByTournament(Tournament tournament);

    // In the order they were added
    @Query("SELECT c FROM TournamentCoOrganizer c JOIN FETCH c.player WHERE c.tournament = :tournament ORDER BY c.createdAt ASC, c.id ASC")
    List<TournamentCoOrganizer> findAllByTournament(@Param("tournament") Tournament tournament);

    @Query("SELECT c.player.playerId FROM TournamentCoOrganizer c WHERE c.tournament = :tournament")
    List<Long> findPlayerIds(@Param("tournament") Tournament tournament);

    @Query("SELECT c.tournament.id FROM TournamentCoOrganizer c WHERE c.player = :player")
    List<Long> findTournamentIds(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM TournamentCoOrganizer c WHERE c.tournament = :tournament")
    void deleteAllByTournament(@Param("tournament") Tournament tournament);

    @Modifying
    @Query("DELETE FROM TournamentCoOrganizer c WHERE c.player = :player")
    void deleteAllByPlayer(@Param("player") Player player);
}
