package com.example.gamify.dto;

import com.example.gamify.entity.Game;
import com.example.gamify.entity.TournamentStatus;

import java.time.OffsetDateTime;

/**
 * A tournament as seen by the current player. {@code myStatus} is ORGANIZER, PENDING, ACCEPTED,
 * REJECTED, or NONE when they haven't asked to join.
 */
public record TournamentSummaryResponse(
        Long id,
        String name,
        Game game,
        String description,
        OffsetDateTime startsAt,
        Integer maxParticipants,
        long participantCount,
        TournamentStatus status,
        PlayerSummaryResponse organizer,
        MyStatus myStatus,
        OffsetDateTime completedAt
) {
    public enum MyStatus { ORGANIZER, PENDING, ACCEPTED, REJECTED, NONE }
}
