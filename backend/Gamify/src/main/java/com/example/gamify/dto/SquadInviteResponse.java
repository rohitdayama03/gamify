package com.example.gamify.dto;

import java.time.OffsetDateTime;

/** An invite to join a squad. {@code invitedBy} is null if the inviter has since deleted their account. */
public record SquadInviteResponse(
        Long id,
        Long squadId,
        String squadName,
        PlayerSummaryResponse invitedBy,
        long memberCount,
        OffsetDateTime createdAt
) {}
