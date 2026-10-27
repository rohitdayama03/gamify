package com.example.gamify.news;

import com.example.gamify.service.NewsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;

/** Pulls the news feeds once a day, and on startup if the stored news is more than a day old. */
@Slf4j
@Component
@RequiredArgsConstructor
public class NewsFeedScheduler {

    private final NewsService newsService;

    @Scheduled(cron = "${app.news.cron}", zone = "${app.news.zone}")
    public void dailyRefresh() {
        refresh("daily schedule");
    }

    // So a fresh deploy or a server that was down overnight doesn't wait until the next scheduled run
    @EventListener(ApplicationReadyEvent.class)
    public void refreshIfStale() {
        boolean stale = newsService.lastFetchTime()
                .map(last -> last.isBefore(OffsetDateTime.now().minusHours(24)))
                .orElse(true);
        if (stale) {
            refresh("startup");
        }
    }

    private void refresh(String reason) {
        try {
            int added = newsService.refreshFeeds();
            log.info("News refresh ({}) added {} items", reason, added);
        } catch (Exception e) {
            // Never let a news failure take the app down
            log.error("News refresh ({}) failed", reason, e);
        }
    }
}
