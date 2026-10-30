package com.example.gamify.service;

import com.example.gamify.dto.PlayerResponse;
import com.example.gamify.entity.Game;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface PlayerSearchService {
    /**
     * @param currentUsername the caller, who is left out of the results
     * @param searchText  free text matched against usernames (prefix) and game names; ignored if blank
     * @param matchedGame the game [searchText] names, if any, so its players are included
     */
    Page<PlayerResponse> searchPlayers(
            String currentUsername,
            String searchText,
            Game matchedGame,
            String username,
            String country,
            String language,
            Game game,
            String gtaPlatform,
            String gtaActivity,
            String bgmiRole,
            String efootballTier,
            Pageable pageable
    );
}