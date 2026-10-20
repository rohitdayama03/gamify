package com.example.gamify.dto;

import jakarta.validation.constraints.Size;

// Profile DTOs
public record UpdatePlayerRequest(
        String playerBio,
        @Size(max = 255) String language,
        @Size(max = 50) String country
) {}
