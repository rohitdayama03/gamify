package com.example.gamify.service;

import com.example.gamify.dto.NewsItemResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface NewsService {

    /** Stored headlines, newest first. */
    Page<NewsItemResponse> getNews(Pageable pageable);

    /** Pulls the configured feeds, stores the newest items not seen before, and prunes old ones. Returns how many were added. */
    int refreshFeeds();

    Optional<OffsetDateTime> lastFetchTime();
}
