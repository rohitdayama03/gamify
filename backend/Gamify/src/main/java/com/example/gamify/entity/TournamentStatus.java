package com.example.gamify.entity;

/**
 * OPEN while players join. A tournament with stages becomes IN_PROGRESS when the organizer starts it,
 * which locks the fixtures. COMPLETED once the result is recorded or the last stage is finished.
 */
public enum TournamentStatus {
    OPEN,
    IN_PROGRESS,
    COMPLETED
}
