package com.example.gamify.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.util.List;

/**
 * {@code winner} is who the organizer picked: HOME, AWAY, or DRAW (group and league stages only). It must agree
 * with the final score; a level knockout match goes to the picked winner, with the shootout score optional.
 * Apps before the winner picker leave it null, and the winner comes from the score and penalties as before.
 * A stat value left null isn't recorded.
 */
public record MatchResultRequest(
        Winner winner,
        @NotNull(message = "Enter both scores") @Min(0) @Max(99) Integer homeScore,
        @NotNull(message = "Enter both scores") @Min(0) @Max(99) Integer awayScore,
        @Min(0) @Max(99) Integer homePens,
        @Min(0) @Max(99) Integer awayPens,
        @Size(max = 8) List<@Valid @NotNull StatValue> stats
) {
    public enum Winner { HOME, AWAY, DRAW }

    public record StatValue(
            @NotNull Long statId,
            @PositiveOrZero @Max(100000) Double home,
            @PositiveOrZero @Max(100000) Double away
    ) {}
}
