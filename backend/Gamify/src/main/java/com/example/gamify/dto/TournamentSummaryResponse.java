package com.example.gamify.dto;

import com.example.gamify.entity.Game;
import com.example.gamify.entity.TournamentStatus;

import java.time.OffsetDateTime;

/**
 * A tournament as seen by the current player. {@code myStatus} is ORGANIZER, PENDING, ACCEPTED,
 * REJECTED, or NONE when they haven't asked to join. {@code amPlaying} is true when they're an accepted
 * player; it's the only way to tell an organizer who has entered their own tournament, whose
 * {@code myStatus} stays ORGANIZER. {@code slots} is set for a tournament with a format.
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
        boolean amPlaying,
        OffsetDateTime completedAt,
        Integer slots
) {
    public enum MyStatus { ORGANIZER, PENDING, ACCEPTED, REJECTED, NONE }
}
