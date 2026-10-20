package com.example.gamify.dto;

public record ConversationResponse(
        PlayerSummaryResponse friend,
        ChatMessageResponse lastMessage,
        long unreadCount
) {}
