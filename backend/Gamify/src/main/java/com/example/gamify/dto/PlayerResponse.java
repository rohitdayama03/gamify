package com.example.gamify.dto;

import com.example.gamify.entity.Game;

import java.time.OffsetDateTime;
import java.util.List;

// phoneNumber is only filled in for the signed-in player's own profile
public record PlayerResponse(
        Long playerId,
        String username,
        // Signed S3 link to their profile picture, or null if they have none
        String avatarUrl,
        String phoneNumber,
        String playerBio,
        String language,
        String country,
        List<Game> interestedGames,
        Game lastGame,
        GtaProfileResponse gtaProfile,
        BgmiProfileResponse bgmiProfile,
        EfootballProfileResponse efootballProfile,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {}
