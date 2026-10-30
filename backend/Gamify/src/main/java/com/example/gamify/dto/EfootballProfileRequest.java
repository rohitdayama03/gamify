package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record EfootballProfileRequest(
        @NotBlank @Size(max = 50) String inGameName,
        @NotBlank String efootballId,
        String highTier
) {}
