package com.example.gamify.dto;

import com.example.gamify.entity.Game;
import jakarta.validation.constraints.*;

import java.time.OffsetDateTime;

/** {@code maxParticipants} is optional; null means no limit. */
public record CreateTournamentRequest(
        @NotBlank(message = "Tournament name is required")
        @Size(min = 3, max = 60, message = "Tournament name must be 3 to 60 characters")
        String name,
        @NotNull(message = "Pick the game") Game game,
        @Size(max = 1000, message = "Description can be at most 1000 characters") String description,
        @NotNull(message = "Pick when it starts")
        @Future(message = "The start time must be in the future")
        OffsetDateTime startsAt,
        @Min(value = 2, message = "Allow at least 2 participants")
        @Max(value = 1000, message = "At most 1000 participants")
        Integer maxParticipants
) {}
