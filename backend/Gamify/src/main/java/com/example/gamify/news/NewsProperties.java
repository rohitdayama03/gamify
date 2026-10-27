package com.example.gamify.news;

import com.example.gamify.entity.Game;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

/**
 * News sources from application.properties (app.news.*). Each source is a group of feeds pulled together,
 * with its own daily limit; a feed may name the game all its stories are about.
 */
@ConfigurationProperties(prefix = "app.news")
public record NewsProperties(int retentionDays, List<Source> sources) {

    /** @param dailyLimit most new stories taken from this source per pull, shared across its feeds */
    public record Source(String name, int dailyLimit, List<Feed> feeds) {}

    /**
     * @param game       set for game-specific feeds; otherwise stories are tagged by keywords in their title
     * @param matchTitle for a game-specific feed, whether a story's title must name the game to be kept. On by
     *                   default (searches and multi-game channels); turn off for channels that only cover that game.
     */
    public record Feed(String url, Game game, Boolean matchTitle) {
        public boolean requiresTitleMatch() {
            return game != null && !Boolean.FALSE.equals(matchTitle);
        }
    }
}
