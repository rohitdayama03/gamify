package com.example.gamify.controller;

import com.example.gamify.dto.PlayerResponse;
import com.example.gamify.entity.Game;
import com.example.gamify.service.PlayerSearchService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/players")
@RequiredArgsConstructor
public class PlayerSearchController {

    private final PlayerSearchService searchService;

    // Tells the client which game the search text named, so it can label the results
    public static final String MATCHED_GAME_HEADER = "X-Matched-Game";

    @GetMapping("/search")
    public ResponseEntity<Page<PlayerResponse>> searchPlayers(
            @AuthenticationPrincipal String currentUsername,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String country,
            @RequestParam(required = false) String language,
            @RequestParam(required = false) Game game,
            @RequestParam(required = false) String gtaPlatform,
            @RequestParam(required = false) String gtaActivity,
            @RequestParam(required = false) String bgmiRole,
            @RequestParam(required = false) String efootballTier,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "DESC") String sortDirection
    ) {
        // Text shorter than 3 characters is too broad to search on, so it is ignored
        String searchText = q != null && q.trim().length() >= Game.MIN_QUERY_LENGTH ? q.trim() : null;
        Game matchedGame = searchText == null ? null : Game.fromSearchText(searchText);

        // Free-text results are ranked by the search itself (username matches first), so no column sort
        Sort sort = sortDirection.equalsIgnoreCase("ASC") ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = searchText == null ? PageRequest.of(page, size, sort) : PageRequest.of(page, size);

        Page<PlayerResponse> result = searchService.searchPlayers(
                currentUsername, searchText, matchedGame, username, country, language, game, gtaPlatform, gtaActivity, bgmiRole, efootballTier, pageable
        );

        ResponseEntity.BodyBuilder response = ResponseEntity.ok();
        if (matchedGame != null) {
            response.header(MATCHED_GAME_HEADER, matchedGame.name());
        }
        return response.body(result);
    }
}