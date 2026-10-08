package com.example.gamify.controller;

import com.example.gamify.dto.PlayerResponse;
import com.example.gamify.service.PlayerSearchService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/players")
@RequiredArgsConstructor
public class PlayerSearchController {

    private final PlayerSearchService searchService;

    @GetMapping("/search")
    public ResponseEntity<Page<PlayerResponse>> searchPlayers(
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String country,
            @RequestParam(required = false) String language,
            @RequestParam(required = false) String bgmiRole,
            @RequestParam(required = false) String efootballTier,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "DESC") String sortDirection
    ) {
        Sort sort = sortDirection.equalsIgnoreCase("ASC") ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);

        Page<PlayerResponse> result = searchService.searchPlayers(
                username, country, language, bgmiRole, efootballTier, pageable
        );

        return ResponseEntity.ok(result);
    }
}