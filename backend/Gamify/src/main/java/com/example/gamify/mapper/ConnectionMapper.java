package com.example.gamify.mapper;

import com.example.gamify.dto.ConnectionResponse;
import com.example.gamify.dto.PlayerSummaryResponse;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.PlayerConnection;
import com.example.gamify.media.MediaStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class ConnectionMapper {

    private final MediaStorage mediaStorage;

    public ConnectionResponse toConnectionResponse(PlayerConnection connection, Player currentPlayer) {
        boolean sentByMe = connection.getSender().getPlayerId().equals(currentPlayer.getPlayerId());
        Player other = sentByMe ? connection.getReceiver() : connection.getSender();

        return new ConnectionResponse(
                connection.getId(),
                toPlayerSummary(other),
                sentByMe ? ConnectionResponse.Direction.SENT : ConnectionResponse.Direction.RECEIVED,
                connection.getStatus(),
                connection.getCreatedAt(),
                connection.getRespondedAt()
        );
    }

    public PlayerSummaryResponse toPlayerSummary(Player player) {
        return new PlayerSummaryResponse(
                player.getPlayerId(),
                player.getUsername(),
                mediaStorage.url(player.getAvatarKey()),
                player.getPlayerBio(),
                player.getCountry(),
                player.getLanguage()
        );
    }
}
