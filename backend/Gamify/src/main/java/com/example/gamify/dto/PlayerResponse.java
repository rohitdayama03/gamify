package com.example.gamify.dto;

import java.time.OffsetDateTime;

public record PlayerResponse(
        Long playerId,
        String username,
        String playerBio,
        String language,
        String country,
        BgmiProfileResponse bgmiProfile,
        EfootballProfileResponse efootballProfile,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {}
