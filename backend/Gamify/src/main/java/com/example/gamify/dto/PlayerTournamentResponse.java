package com.example.gamify.dto;

import com.example.gamify.entity.Game;
import com.example.gamify.entity.TournamentStatus;

import java.time.OffsetDateTime;

/** A tournament on a player's profile. {@code placement} is null until results are in, or if unplaced. */
public record PlayerTournamentResponse(
        Long id,
        String name,
        Game game,
        OffsetDateTime startsAt,
        TournamentStatus status,
        Integer placement,
        long participantCount,
        String organizerUsername
) {}
