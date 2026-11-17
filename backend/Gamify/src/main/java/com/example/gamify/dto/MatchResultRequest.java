package com.example.gamify.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.util.List;

/** Penalties only for a level knockout match. A stat value left null isn't recorded. */
public record MatchResultRequest(
        @NotNull(message = "Enter both scores") @Min(0) @Max(99) Integer homeScore,
        @NotNull(message = "Enter both scores") @Min(0) @Max(99) Integer awayScore,
        @Min(0) @Max(99) Integer homePens,
        @Min(0) @Max(99) Integer awayPens,
        @Size(max = 8) List<@Valid @NotNull StatValue> stats
) {
    public record StatValue(
            @NotNull Long statId,
            @PositiveOrZero @Max(100000) Double home,
            @PositiveOrZero @Max(100000) Double away
    ) {}
}
