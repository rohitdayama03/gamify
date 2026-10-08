package com.example.gamify.mapper;

import com.example.gamify.dto.*;
import com.example.gamify.entity.BgmiProfile;
import com.example.gamify.entity.EfootballProfile;
import com.example.gamify.entity.Player;
import org.springframework.stereotype.Component;

@Component
public class PlayerMapper {

    public PlayerResponse toPlayerResponse(Player player) {
        if (player == null) {
            return null;
        }

        BgmiProfileResponse bgmiResponse = toBgmiProfileResponse(player.getBgmiProfile());
        EfootballProfileResponse efootballResponse = toEfootballProfileResponse(player.getEfootballProfile());

        return new PlayerResponse(
                player.getPlayerId(),
                player.getUsername(),
                player.getPlayerBio(),
                player.getLanguage(),
                player.getCountry(),
                bgmiResponse,
                efootballResponse
        );
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