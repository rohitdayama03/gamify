package com.example.gamify.dto;

import jakarta.validation.constraints.*;

// Auth DTOs
// Bio, languages and interested games are collected in onboarding after the account exists
public record RegisterRequest(
        @NotBlank @Size(min = 3, max = 50) String username,
        @NotBlank @Email @Size(max = 255) String email,
        @NotBlank @Size(min = 6) String password,
        String playerBio,
        @Size(max = 255) String language,
        @Size(max = 50) String country,
        @NotBlank String secretQuestion,
        @NotBlank String secretAnswer,
        @NotNull @AssertTrue(message = "You must accept the terms to create an account") Boolean acceptedTerms
) {}
