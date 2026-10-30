package com.example.gamify.controller;

import com.example.gamify.dto.FeedPageResponse;
import com.example.gamify.feed.FeedService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/feed")
@RequiredArgsConstructor
public class FeedController {

    private final FeedService feedService;

    // Friends' posts and your own, best first, with news worked in; pass nextCursor for the next page
    @GetMapping
    public ResponseEntity<FeedPageResponse> getFeed(
            @AuthenticationPrincipal String currentUsername,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "" + FeedService.DEFAULT_PAGE_SIZE) int size) {
        return ResponseEntity.ok(feedService.getFeed(currentUsername, cursor,
                Math.min(Math.max(size, 1), FeedService.MAX_PAGE_SIZE)));
    }
}
