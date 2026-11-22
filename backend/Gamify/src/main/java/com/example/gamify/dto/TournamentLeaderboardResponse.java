package com.example.gamify.dto;

import java.util.List;

/**
 * {@code overall}: every player across all matches, by points, then goal difference, then goals scored, with
 * their stat totals (or averages). {@code stages}: the table of each league group; knockouts appear in the
 * fixtures instead. A stage that hasn't begun has no groups yet. {@code points} are what a win, draw and loss
 * are worth in these tables.
 */
public record TournamentLeaderboardResponse(
        TournamentFormatResponse.Points points,
        List<TournamentFormatResponse.Stat> stats,
        List<Row> overall,
        List<StageTable> stages
) {
    public record Row(
            Long participantId,
            PlayerSummaryResponse player,
            // Final position once decided (1 = champion)
            Integer placement,
            Record record,
            List<TournamentFixturesResponse.StatValue> stats
    ) {}

    public record StageTable(Long stageId, int seq, boolean finished, List<Group> groups) {}

    public record Group(int groupNo, String name, int advancing, List<StandingRow> rows) {}

    // tied: level with a neighbour on every tiebreaker; rows sharing a tieBlock are level with each other and only they may
    // swap places when the organizer finishes the stage. qualified: goes (or went) through to the next stage.
    public record StandingRow(Long participantId, PlayerSummaryResponse player, Record record, boolean tied, int tieBlock, boolean qualified) {}

    public record Record(int played, int won, int drawn, int lost, int goalsFor, int goalsAgainst, int goalDifference, int points) {}
}
