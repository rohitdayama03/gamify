package com.example.gamify.service;

import com.example.gamify.dto.PlayerResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface PlayerSearchService {
    Page<PlayerResponse> searchPlayers(
            String username,
            String country,
            String language,
            String bgmiRole,
            String efootballTier,
            Pageable pageable
    );
}