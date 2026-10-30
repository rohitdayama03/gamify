package com.example.gamify.dto;

import java.util.List;

/**
 * {@code participants} holds accepted players for everyone; the organizer also gets pending and rejected
 * requests. Placed players come first, winner on top.
 */
public record TournamentDetailResponse(
        TournamentSummaryResponse tournament,
        List<TournamentParticipantResponse> participants,
        String resultNotes
) {}
