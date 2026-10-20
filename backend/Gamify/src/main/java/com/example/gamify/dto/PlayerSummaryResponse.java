package com.example.gamify.dto;

public record PlayerSummaryResponse(
        Long playerId,
        String username,
        String playerBio,
        String country,
        String language
) {}
