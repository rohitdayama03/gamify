package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;

public record EfootballProfileRequest(
        @NotBlank String efootballId,
        String highTier
) {}
