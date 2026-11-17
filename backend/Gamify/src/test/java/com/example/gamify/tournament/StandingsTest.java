package com.example.gamify.tournament;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class StandingsTest {

    private static Standings.Result r(long home, long away, int hs, int as) {
        return new Standings.Result(home, away, hs, as);
    }

    @Test
    void twoPointsForAWinOneForADraw() {
        // 1 beats 2, 2 draws 3, 3 draws 1
        List<Standings.Row> rows = Standings.rank(List.of(1L, 2L, 3L), List.of(r(1, 2, 2, 0), r(2, 3, 1, 1), r(3, 1, 0, 0)));
        assertEquals(List.of(1L, 3L, 2L), rows.stream().map(Standings.Row::participantId).toList());
        assertEquals(List.of(3, 2, 1), rows.stream().map(Standings.Row::points).toList());
        assertEquals(1, rows.get(0).won());
        assertEquals(1, rows.get(0).drawn());
        assertEquals(1, rows.get(2).lost());
        assertEquals(2, rows.get(1).played());
    }

    @Test
    void goalDifferenceThenGoalsScored() {
        // 1 and 2 both win once; 1 by more
        List<Standings.Row> rows = Standings.rank(List.of(1L, 2L, 3L, 4L), List.of(r(1, 3, 3, 0), r(2, 4, 1, 0)));
        assertEquals(List.of(1L, 2L), rows.subList(0, 2).stream().map(Standings.Row::participantId).toList());
        // Same difference, more goals wins
        rows = Standings.rank(List.of(1L, 2L, 3L, 4L), List.of(r(1, 3, 1, 0), r(2, 4, 3, 2)));
        assertEquals(2L, rows.get(0).participantId());
    }

    @Test
    void headToHeadSettlesLevelPlayers() {
        // 1 and 2 finish level on points, goal difference and goals; 2 won their meeting
        List<Standings.Result> results = List.of(
                r(2, 1, 1, 0),  // 2 beats 1
                r(1, 3, 2, 0),  // 1 beats 3 by 2
                r(2, 3, 0, 1),  // 3 beats 2
                r(1, 4, 1, 0),
                r(2, 4, 2, 0),
                r(3, 4, 0, 1));
        // 1: W W L = 4 pts, GF 3 GA 1; 2: W L W = 4 pts, GF 3 GA 1 -> level, 2 beat 1
        List<Standings.Row> rows = Standings.rank(List.of(1L, 2L, 3L, 4L), results);
        assertEquals(2L, rows.get(0).participantId());
        assertEquals(1L, rows.get(1).participantId());
        assertNotEquals(rows.get(0).tieBlock(), rows.get(1).tieBlock());
    }

    @Test
    void fullyLevelPlayersShareATieBlock() {
        List<Standings.Row> rows = Standings.rank(List.of(1L, 2L, 3L), List.of(r(1, 2, 1, 1), r(3, 1, 0, 0), r(2, 3, 0, 0)));
        // Everyone drew; 1 and 2 scored 1, 3 scored 0
        assertEquals(rows.get(0).tieBlock(), rows.get(1).tieBlock());
        assertTrue(Standings.isTied(rows, 0));
        assertFalse(Standings.isTied(rows, 2));
        assertEquals(3L, rows.get(2).participantId());
    }

    @Test
    void playersWithNoMatchesAreListed() {
        List<Standings.Row> rows = Standings.rank(List.of(5L, 6L), List.of());
        assertEquals(2, rows.size());
        assertEquals(0, rows.get(0).played());
    }
}
