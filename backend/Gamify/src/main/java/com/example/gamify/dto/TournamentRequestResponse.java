package com.example.gamify.dto;

import com.example.gamify.entity.Game;

import java.time.OffsetDateTime;

/** A pending join request, shown to the organizer. */
public record TournamentRequestResponse(
        Long id,
        Long tournamentId,
        String tournamentName,
        Game game,
        PlayerSummaryResponse player,
        OffsetDateTime requestedAt
) {}
