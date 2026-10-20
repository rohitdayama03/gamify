package com.example.gamify.dto;

import java.time.OffsetDateTime;

/**
 * {@code fromMe} is true when the current player sent the message.
 */
public record ChatMessageResponse(
        Long id,
        Long senderId,
        Long receiverId,
        String content,
        boolean fromMe,
        OffsetDateTime createdAt,
        OffsetDateTime readAt
) {}
