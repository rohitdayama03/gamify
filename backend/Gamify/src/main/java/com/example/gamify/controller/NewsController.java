package com.example.gamify.controller;

import com.example.gamify.dto.NewsItemResponse;
import com.example.gamify.service.NewsService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/news")
@RequiredArgsConstructor
public class NewsController {

    private static final int MAX_PAGE_SIZE = 50;

    private final NewsService newsService;

    // Gaming headlines, newest first; signed-in players only
    @GetMapping
    public ResponseEntity<Page<NewsItemResponse>> getNews(
            @AuthenticationPrincipal String currentUsername,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        PageRequest pageRequest = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), MAX_PAGE_SIZE));
        return ResponseEntity.ok(newsService.getNews(pageRequest));
    }
}
