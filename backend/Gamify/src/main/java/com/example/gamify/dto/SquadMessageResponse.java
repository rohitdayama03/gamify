package com.example.gamify.dto;

import java.time.OffsetDateTime;

/**
 * {@code fromMe} is true when the current player sent the message.
 */
public record SquadMessageResponse(
        Long id,
        Long squadId,
        Long senderId,
        String senderUsername,
        String content,
        boolean fromMe,
        OffsetDateTime createdAt
) {}
