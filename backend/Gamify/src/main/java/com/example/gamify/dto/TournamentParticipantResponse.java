package com.example.gamify.dto;

import com.example.gamify.entity.ParticipantStatus;

import java.time.OffsetDateTime;

/**
 * {@code id} is the join request's id, used to accept or reject it. {@code slotNo} is the player's place in the
 * draw once a tournament with a format has started.
 */
public record TournamentParticipantResponse(
        Long id,
        PlayerSummaryResponse player,
        ParticipantStatus status,
        Integer placement,
        OffsetDateTime requestedAt,
        Integer slotNo
) {}
