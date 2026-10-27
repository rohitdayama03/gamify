package com.example.gamify.dto;

import com.example.gamify.entity.Game;
import jakarta.validation.constraints.Size;

import java.util.List;

// Profile DTOs; null fields are left unchanged
public record UpdatePlayerRequest(
        String playerBio,
        @Size(max = 255) String language,
        @Size(max = 50) String country,
        @Size(min = 1, max = 3, message = "Choose between 1 and 3 games") List<Game> interestedGames,
        Game lastGame
) {}
