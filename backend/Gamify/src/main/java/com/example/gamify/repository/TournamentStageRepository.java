package com.example.gamify.repository;

import com.example.gamify.entity.Tournament;
import com.example.gamify.entity.TournamentStage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TournamentStageRepository extends JpaRepository<TournamentStage, Long> {

    List<TournamentStage> findAllByTournamentOrderBySeqAsc(Tournament tournament);

    @Modifying
    @Query("DELETE FROM TournamentStage s WHERE s.tournament = :tournament")
    void deleteAllByTournament(@Param("tournament") Tournament tournament);
}
