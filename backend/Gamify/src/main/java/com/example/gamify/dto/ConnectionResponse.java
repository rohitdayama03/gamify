package com.example.gamify.dto;

import com.example.gamify.entity.ConnectionStatus;

import java.time.OffsetDateTime;

/**
 * A connection seen from the current player's side: {@code direction} is SENT when the
 * current player sent the invite, RECEIVED otherwise, and {@code otherPlayer} is the other side.
 */
public record ConnectionResponse(
        Long id,
        PlayerSummaryResponse otherPlayer,
        Direction direction,
        ConnectionStatus status,
        OffsetDateTime createdAt,
        OffsetDateTime respondedAt
) {
    public enum Direction { SENT, RECEIVED }
}
