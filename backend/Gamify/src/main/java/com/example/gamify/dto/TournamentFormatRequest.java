package com.example.gamify.dto;

import com.example.gamify.entity.StageType;
import com.example.gamify.entity.StatAggregation;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.util.List;

/**
 * Number of players, stages in play order and stat columns (eFootball only). League fields are ignored for a
 * knockout stage and vice versa; {@code advancePerGroup} is ignored in the last stage.
 */
public record TournamentFormatRequest(
        @NotNull(message = "Pick the number of players")
        @Min(value = 2, message = "A tournament needs at least 2 players")
        @Max(value = 64, message = "A tournament can have at most 64 players")
        Integer slots,
        @NotEmpty(message = "Add at least one stage")
        @Size(max = 4, message = "A tournament can have at most 4 stages")
        List<@Valid @NotNull Stage> stages,
        @Size(max = 8, message = "Pick at most 8 stats")
        List<@Valid @NotNull Stat> stats
) {
    public record Stage(
            @NotNull(message = "Pick a type for every stage") StageType type,
            Integer groupCount,
            Integer rounds,
            Integer advancePerGroup,
            Boolean thirdPlace
    ) {}

    public record Stat(
            @NotBlank(message = "Name every stat")
            @Size(max = 20, message = "Stat names can be at most 20 characters")
            String label,
            @NotNull StatAggregation aggregation
    ) {}
}
