package com.example.gamify.dto;

import jakarta.validation.constraints.*;

// Auth DTOs
// Bio, languages and interested games are collected in onboarding after the account exists.
// The code is proven like on LoginRequest: accessToken from MSG91, or otp when testing without it
public record RegisterRequest(
        @NotBlank @Size(min = 3, max = 50) String username,
        @NotBlank @Pattern(regexp = PhoneNumbers.PATTERN, message = PhoneNumbers.MESSAGE) String phoneNumber,
        String otp,
        String accessToken,
        String playerBio,
        @Size(max = 255) String language,
        @Size(max = 50) String country,
        @NotNull @AssertTrue(message = "You must accept the terms to create an account") Boolean acceptedTerms
) {}
