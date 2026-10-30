package com.example.gamify.mapper;

import com.example.gamify.dto.SquadInviteResponse;
import com.example.gamify.dto.SquadMemberResponse;
import com.example.gamify.dto.SquadMessageResponse;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.SquadMember;
import com.example.gamify.entity.SquadMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class SquadMapper {

    private final ConnectionMapper connectionMapper;

    public SquadMessageResponse toMessageResponse(SquadMessage message, Player currentPlayer) {
        Player sender = message.getSender();
        return new SquadMessageResponse(
                message.getId(),
                message.getSquad().getId(),
                sender.getPlayerId(),
                sender.getUsername(),
                message.getContent(),
                sender.getPlayerId().equals(currentPlayer.getPlayerId()),
                message.getCreatedAt()
        );
    }

    public SquadMemberResponse toMemberResponse(SquadMember member) {
        return new SquadMemberResponse(
                connectionMapper.toPlayerSummary(member.getPlayer()),
                member.getStatus(),
                member.getCreatedAt(),
                member.getJoinedAt()
        );
    }

    public SquadInviteResponse toInviteResponse(SquadMember invite, long memberCount) {
        Player inviter = invite.getInvitedBy();
        return new SquadInviteResponse(
                invite.getId(),
                invite.getSquad().getId(),
                invite.getSquad().getName(),
                inviter == null ? null : connectionMapper.toPlayerSummary(inviter),
                memberCount,
                invite.getCreatedAt()
        );
    }
}
