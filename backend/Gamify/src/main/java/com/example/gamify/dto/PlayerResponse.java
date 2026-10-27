package com.example.gamify.dto;

import com.example.gamify.entity.Game;

import java.time.OffsetDateTime;
import java.util.List;

// email is only filled in for the signed-in player's own profile
public record PlayerResponse(
        Long playerId,
        String username,
        String email,
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
