package com.example.gamify.dto;

public record BgmiProfileResponse(
        Long id,
        String inGameName,
        String bgmiId,
        String currentRole,
        String experience,
        String availableTime,
        String achievements,
        String lookingFor
) {}
