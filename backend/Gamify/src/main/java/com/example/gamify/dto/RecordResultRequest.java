package com.example.gamify.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Placements for accepted participants (1 = winner; ties allowed). Unlisted participants get no placement. */
public record RecordResultRequest(
        @NotEmpty(message = "Place at least one participant") List<@Valid Placement> placements,
        @Size(max = 1000, message = "Notes can be at most 1000 characters") String notes
) {
    public record Placement(
            @NotNull Long playerId,
            @NotNull @Min(value = 1, message = "Placements start at 1") Integer placement
    ) {}
}
