package com.example.gamify.dto;

import com.example.gamify.entity.StageType;
import com.example.gamify.entity.StatAggregation;

import java.util.List;

/**
 * A tournament's format. {@code currentStageId} is the first unfinished stage once the tournament has started
 * (null before the start and after the end). {@code editable} is true while the organizer may still change the
 * format: before anyone has been accepted.
 */
public record TournamentFormatResponse(
        int slots,
        List<Stage> stages,
        List<Stat> stats,
        Long currentStageId,
        boolean editable
) {
    public record Stage(
            Long id,
            int seq,
            StageType type,
            int entrants,
            int groupCount,
            int rounds,
            int advancePerGroup,
            boolean thirdPlace,
            boolean finished,
            int matchCount,
            int completedCount
    ) {}

    public record Stat(Long id, String label, StatAggregation aggregation) {}
}
