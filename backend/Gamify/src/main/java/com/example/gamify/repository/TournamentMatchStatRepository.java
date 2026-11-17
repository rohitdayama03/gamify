package com.example.gamify.repository;

import com.example.gamify.entity.Tournament;
import com.example.gamify.entity.TournamentMatch;
import com.example.gamify.entity.TournamentMatchStat;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TournamentMatchStatRepository extends JpaRepository<TournamentMatchStat, Long> {

    @Query("SELECT v FROM TournamentMatchStat v WHERE v.match.stage.tournament = :tournament")
    List<TournamentMatchStat> findAllByTournament(@Param("tournament") Tournament tournament);

    @Modifying
    @Query("DELETE FROM TournamentMatchStat v WHERE v.match = :match")
    void deleteAllByMatch(@Param("match") TournamentMatch match);

    @Modifying
    @Query("""
            DELETE FROM TournamentMatchStat v WHERE v.match.id IN
            (SELECT m.id FROM TournamentMatch m WHERE m.stage.tournament = :tournament)
            """)
    void deleteAllByTournament(@Param("tournament") Tournament tournament);
}
