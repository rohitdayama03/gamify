package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record BgmiProfileRequest(
        @NotBlank @Size(max = 50) String inGameName,
        @NotBlank String bgmiId,
        String currentRole,
        String experience,
        String availableTime,
        String achievements,
        String lookingFor
) {}
