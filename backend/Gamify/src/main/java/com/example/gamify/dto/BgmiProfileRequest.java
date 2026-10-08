package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;

public record BgmiProfileRequest(
        @NotBlank String bgmiId,
        String currentRole,
        String experience,
        String availableTime,
        String achievements,
        String lookingFor
) {}
