package com.example.gamify.config;

import com.example.gamify.news.NewsProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

// Enables @Scheduled jobs (the daily news pull) and @Async work (sending push notifications)
@Configuration
@EnableScheduling
@EnableAsync
@EnableConfigurationProperties(NewsProperties.class)
public class SchedulingConfig {
}
