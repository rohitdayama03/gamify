package com.example.gamify.dto;

import java.util.List;

/**
 * {@code participants} holds accepted players for everyone; the organizer also gets pending and rejected
 * requests. Placed players come first, winner on top. {@code format} is null for a simple tournament.
 * {@code coOrganizers} are the players the creator added to help run it, in the order they were added.
 */
public record TournamentDetailResponse(
        TournamentSummaryResponse tournament,
        List<TournamentParticipantResponse> participants,
        String resultNotes,
        TournamentFormatResponse format,
        List<PlayerSummaryResponse> coOrganizers
) {}
