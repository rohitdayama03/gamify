package com.example.gamify.dto;

import com.example.gamify.entity.Game;

import java.time.OffsetDateTime;

public record NewsItemResponse(
        Long id,
        String title,
        String summary,
        String imageUrl,
        boolean video,
        String link,
        String category,
        String author,
        String source,
        Game game,
        OffsetDateTime publishedAt
) {}
