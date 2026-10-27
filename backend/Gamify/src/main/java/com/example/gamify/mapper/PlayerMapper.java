package com.example.gamify.mapper;

import com.example.gamify.dto.*;
import com.example.gamify.entity.BgmiProfile;
import com.example.gamify.entity.EfootballProfile;
import com.example.gamify.entity.Game;
import com.example.gamify.entity.GtaProfile;
import com.example.gamify.entity.Player;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@Component
public class PlayerMapper {

    public PlayerResponse toPlayerResponse(Player player) {
        return toPlayerResponse(player, false);
    }

    // Includes private account fields; use only for the signed-in player's own profile
    public PlayerResponse toOwnPlayerResponse(Player player) {
        return toPlayerResponse(player, true);
    }

    private PlayerResponse toPlayerResponse(Player player, boolean includePrivate) {
        if (player == null) {
            return null;
        }

        BgmiProfileResponse bgmiResponse = toBgmiProfileResponse(player.getBgmiProfile());
        EfootballProfileResponse efootballResponse = toEfootballProfileResponse(player.getEfootballProfile());

        return new PlayerResponse(
                player.getPlayerId(),
                player.getUsername(),
                includePrivate ? player.getEmail() : null,
                player.getPlayerBio(),
                player.getLanguage(),
                player.getCountry(),
                Game.split(player.getInterestedGames()),
                player.getLastGame(),
                toGtaProfileResponse(player.getGtaProfile()),
                bgmiResponse,
                efootballResponse,
                player.getCreatedAt(),
                player.getUpdatedAt()
        );
    }

    public GtaProfileResponse toGtaProfileResponse(GtaProfile profile) {
        if (profile == null) {
            return null;
        }

        return new GtaProfileResponse(
                profile.getId(),
                profile.getCharacterName(),
                profile.getPlatform(),
                splitList(profile.getActivities()),
                profile.getRank(),
                profile.getUpdatedAt()
        );
    }

    // Multi-select values are stored comma-separated
    public static String joinList(List<String> values) {
        if (values == null) {
            return null;
        }
        return values.stream().map(String::trim).filter(v -> !v.isEmpty()).distinct().collect(Collectors.joining(","));
    }

    public static List<String> splitList(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        return Arrays.stream(value.split(",")).map(String::trim).filter(v -> !v.isEmpty()).toList();
    }

    public BgmiProfileResponse toBgmiProfileResponse(BgmiProfile profile) {
        if (profile == null) {
            return null;
        }

        return new BgmiProfileResponse(
                profile.getId(),
                profile.getBgmiId(),
                profile.getCurrentRole(),
                profile.getExperience(),
                profile.getAvailableTime(),
                profile.getAchievements(),
                profile.getLookingFor()
        );
    }

    public EfootballProfileResponse toEfootballProfileResponse(EfootballProfile profile) {
        if (profile == null) {
            return null;
        }

        return new EfootballProfileResponse(
                profile.getId(),
                profile.getEfootballId(),
                profile.getHighTier()
        );
    }
}