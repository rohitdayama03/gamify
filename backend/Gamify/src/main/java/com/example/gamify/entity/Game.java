package com.example.gamify.entity;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

// Games GAMIFY supports; stored by name, e.g. "GTA,BGMI"
public enum Game {
    GTA("gta", "gta5", "gtav", "gtaonline", "grandtheftauto", "grandtheftautov", "grandtheftautoonline"),
    BGMI("bgmi", "battlegrounds", "battlegroundsmobileindia", "pubg", "pubgmobile"),
    EFOOTBALL("efootball", "pes", "proevolutionsoccer");

    // Shortest text that can name a game, so "gt" or "e" don't match everything
    public static final int MIN_QUERY_LENGTH = 3;

    // Lowercase names with spaces and punctuation removed, e.g. "grandtheftauto"
    private final List<String> aliases;

    Game(String... aliases) {
        this.aliases = List.of(aliases);
    }

    /**
     * The game a search term names, or null. Only the start of a name counts ("bgm" -> BGMI),
     * so usernames that merely begin with a game name ("gtaking") are not treated as that game.
     */
    public static Game fromSearchText(String text) {
        String normalized = normalize(text);
        if (normalized.length() < MIN_QUERY_LENGTH) {
            return null;
        }
        for (Game game : values()) {
            if (game.aliases.stream().anyMatch(alias -> alias.startsWith(normalized))) {
                return game;
            }
        }
        return null;
    }

    private static String normalize(String text) {
        return text == null ? "" : text.toLowerCase().replaceAll("[^a-z0-9]", "");
    }

    private static final String SEPARATOR = ",";

    public static String join(List<Game> games) {
        if (games == null) {
            return null;
        }
        return games.stream().distinct().map(Game::name).collect(Collectors.joining(SEPARATOR));
    }

    // Unknown names (e.g. a game that was removed) are skipped instead of failing the whole profile
    public static List<Game> split(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        return Arrays.stream(value.split(SEPARATOR))
                .map(String::trim)
                .map(name -> Arrays.stream(values()).filter(g -> g.name().equals(name)).findFirst().orElse(null))
                .filter(Objects::nonNull)
                .toList();
    }
}
