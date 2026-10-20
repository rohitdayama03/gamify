package com.example.gamify.dto;

import jakarta.validation.constraints.*;

// Auth DTOs
public record RegisterRequest(
        @NotBlank @Size(min = 3, max = 50) String username,
        @NotBlank @Size(min = 6) String password,
        String playerBio,
        @Size(max = 255) String language,
        @Size(max = 50) String country,
        @NotBlank String secretQuestion,
        @NotBlank String secretAnswer
) {}

