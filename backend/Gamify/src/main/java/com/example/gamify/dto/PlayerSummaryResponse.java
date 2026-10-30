package com.example.gamify.dto;

/** {@code avatarUrl} is a signed S3 link to their profile picture, valid for a limited time, or null if they have none. */
public record PlayerSummaryResponse(
        Long playerId,
        String username,
        String avatarUrl,
        String playerBio,
        String country,
        String language
) {}
