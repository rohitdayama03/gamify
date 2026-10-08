package com.example.gamify.dto;

// Profile DTOs
public record UpdatePlayerRequest(
        String playerBio,
        String language,
        String country
) {}
