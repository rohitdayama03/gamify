package com.example.gamify.dto;

import java.time.OffsetDateTime;
import java.util.List;

/** {@code members} lists joined members in the order they joined, then pending invites. */
public record SquadDetailResponse(
        Long id,
        String name,
        Long ownerId,
        boolean owner,
        List<SquadMemberResponse> members,
        OffsetDateTime createdAt
) {}
