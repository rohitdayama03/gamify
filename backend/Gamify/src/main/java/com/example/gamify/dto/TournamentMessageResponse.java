package com.example.gamify.dto;

import java.time.OffsetDateTime;

/**
 * An organizer announcement. {@code fromMe} is true when the current player sent it.
 */
public record TournamentMessageResponse(
        Long id,
        Long tournamentId,
        Long senderId,
        String senderUsername,
        String content,
        boolean fromMe,
        OffsetDateTime createdAt
) {}
