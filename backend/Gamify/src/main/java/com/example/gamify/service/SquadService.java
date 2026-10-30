package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.Player;

import java.util.List;

public interface SquadService {
    List<SquadSummaryResponse> getMySquads(String username);
    SquadDetailResponse createSquad(String username, CreateSquadRequest request);
    SquadDetailResponse getSquad(String username, Long squadId);
    SquadDetailResponse invite(String username, Long squadId, List<Long> playerIds);
    SquadDetailResponse removeMember(String username, Long squadId, Long playerId);
    void leave(String username, Long squadId);

    List<SquadInviteResponse> getMyInvites(String username);
    SquadDetailResponse acceptInvite(String username, Long inviteId);
    void declineInvite(String username, Long inviteId);

    List<SquadMessageResponse> getMessages(String username, Long squadId, Long afterId, Long beforeId);
    SquadMessageResponse sendMessage(String username, Long squadId, String content);

    /** Takes a player out of every squad before their account is deleted. */
    void removePlayerFromAllSquads(Player player);
}
