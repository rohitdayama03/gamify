package com.example.gamify.repository;

import com.example.gamify.entity.Tournament;
import com.example.gamify.entity.TournamentMatch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TournamentMatchRepository extends JpaRepository<TournamentMatch, Long> {

    // In play order: stage, group, round, match
    @Query("""
            SELECT m FROM TournamentMatch m JOIN FETCH m.stage s
            LEFT JOIN FETCH m.home h LEFT JOIN FETCH h.player
            LEFT JOIN FETCH m.away a LEFT JOIN FETCH a.player
            LEFT JOIN FETCH m.winner
            WHERE s.tournament = :tournament
            ORDER BY s.seq, m.groupNo, m.roundNo, m.matchNo
            """)
    List<TournamentMatch> findAllByTournament(@Param("tournament") Tournament tournament);

    @Modifying
    @Query("DELETE FROM TournamentMatch m WHERE m.stage.id IN (SELECT s.id FROM TournamentStage s WHERE s.tournament = :tournament)")
    void deleteAllByTournament(@Param("tournament") Tournament tournament);
}
