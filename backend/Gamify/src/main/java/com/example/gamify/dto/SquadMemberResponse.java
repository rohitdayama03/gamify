package com.example.gamify.dto;

import com.example.gamify.entity.SquadMemberStatus;

import java.time.OffsetDateTime;

public record SquadMemberResponse(
        PlayerSummaryResponse player,
        SquadMemberStatus status,
        OffsetDateTime invitedAt,
        OffsetDateTime joinedAt
) {}
