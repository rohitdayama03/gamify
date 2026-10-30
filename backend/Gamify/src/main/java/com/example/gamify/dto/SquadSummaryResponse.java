package com.example.gamify.dto;

import java.time.OffsetDateTime;

/** A squad in the chat list. {@code lastMessage} is null until someone writes. */
public record SquadSummaryResponse(
        Long id,
        String name,
        Long ownerId,
        long memberCount,
        SquadMessageResponse lastMessage,
        long unreadCount,
        OffsetDateTime joinedAt
) {}
