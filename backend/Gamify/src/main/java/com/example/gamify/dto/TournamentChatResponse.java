package com.example.gamify.dto;

import com.example.gamify.entity.Game;

import java.time.OffsetDateTime;

/**
 * A tournament's announcements in the chat list. {@code organizer} is true when the current player runs it
 * (and so can post); {@code since} is when they were accepted, or when they created it.
 */
public record TournamentChatResponse(
        Long id,
        String name,
        Game game,
        boolean organizer,
        long participantCount,
        TournamentMessageResponse lastMessage,
        long unreadCount,
        OffsetDateTime since
) {}
