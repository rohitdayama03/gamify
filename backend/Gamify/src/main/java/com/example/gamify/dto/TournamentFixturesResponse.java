package com.example.gamify.dto;

import com.example.gamify.entity.StageType;

import java.util.List;

/**
 * Every fixture, stage by stage. A side shows {@code placeholder} (e.g. "Group A · 1st") until its player is
 * known. {@code editable} tells the organizer the result can be entered or corrected now.
 */
public record TournamentFixturesResponse(List<Stage> stages) {

    public record Stage(Long stageId, int seq, StageType type, boolean finished, boolean current, List<Match> matches) {}

    public record Match(
            Long id,
            Integer groupNo,
            String groupName,
            int roundNo,
            String roundName,
            int matchNo,
            Side home,
            Side away,
            Integer homePens,
            Integer awayPens,
            // Participant id; null before the result and for a league draw
            Long winnerId,
            boolean completed,
            boolean editable
    ) {}

    public record Side(
            String placeholder,
            Long participantId,
            PlayerSummaryResponse player,
            Integer score,
            List<StatValue> stats
    ) {}

    public record StatValue(Long statId, double value) {}
}
