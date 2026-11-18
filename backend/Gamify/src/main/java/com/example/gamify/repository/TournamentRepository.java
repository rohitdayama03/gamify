package com.example.gamify.repository;

import com.example.gamify.entity.Game;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.Tournament;
import com.example.gamify.entity.TournamentStatus;
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

    /*
     * Search by tournament name (anywhere in it) or organizer username (start of it). Patterns arrive
     * lowercased with LIKE wildcards escaped by '\'. Null game or status means any.
     *
     * Best matches first: exact name, exact organizer, name starting with the text, organizer starting with
     * it, a word in the name starting with it, then the name merely containing it. Within each, open
     * tournaments come before live and finished ones, soonest first.
     */
    @Query("""
            SELECT t FROM Tournament t JOIN FETCH t.organizer o
            WHERE (:game IS NULL OR t.game = :game)
            AND (:status IS NULL OR t.status = :status)
            AND (LOWER(t.name) LIKE :contains ESCAPE '\\' OR LOWER(o.username) LIKE :prefix ESCAPE '\\')
            ORDER BY
                CASE
                    WHEN LOWER(t.name) = :exact THEN 0
                    WHEN LOWER(o.username) = :exact THEN 1
                    WHEN LOWER(t.name) LIKE :prefix ESCAPE '\\' THEN 2
                    WHEN LOWER(o.username) LIKE :prefix ESCAPE '\\' THEN 3
                    WHEN LOWER(t.name) LIKE :wordStart ESCAPE '\\' THEN 4
                    ELSE 5
                END,
                CASE t.status
                    WHEN com.example.gamify.entity.TournamentStatus.OPEN THEN 0
                    WHEN com.example.gamify.entity.TournamentStatus.IN_PROGRESS THEN 1
                    ELSE 2
                END,
                t.startsAt ASC, t.id DESC
            """)
    List<Tournament> searchByRelevance(@Param("exact") String exact,
                                       @Param("prefix") String prefix,
                                       @Param("contains") String contains,
                                       @Param("wordStart") String wordStart,
                                       @Param("game") Game game,
                                       @Param("status") TournamentStatus status,
                                       Pageable pageable);

    // Same matches as searchByRelevance, ordered by the Pageable's sort (start time)
    @Query("""
            SELECT t FROM Tournament t JOIN FETCH t.organizer o
            WHERE (:game IS NULL OR t.game = :game)
            AND (:status IS NULL OR t.status = :status)
            AND (LOWER(t.name) LIKE :contains ESCAPE '\\' OR LOWER(o.username) LIKE :prefix ESCAPE '\\')
            """)
    List<Tournament> search(@Param("prefix") String prefix,
                            @Param("contains") String contains,
                            @Param("game") Game game,
                            @Param("status") TournamentStatus status,
                            Pageable pageable);
}
