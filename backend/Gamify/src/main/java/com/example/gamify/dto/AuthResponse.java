package com.example.gamify.dto;

public record AuthResponse(
        String token,
        String tokenType,
        Long playerId,
        String username
) {}
