package com.example.gamify.dto;

public record PlayerResponse(
        Long playerId,
        String username,
        String playerBio,
        String language,
        String country,
        BgmiProfileResponse bgmiProfile,
        EfootballProfileResponse efootballProfile
) {}
