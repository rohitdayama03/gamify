package com.example.gamify.dto;

/** How tournament search results are ordered. */
public enum TournamentSearchSort {
    /** Name and organizer matches ranked by how closely they match, open tournaments first. */
    RELEVANCE,
    /** Earliest start time first. */
    STARTS_EARLIEST,
    /** Latest start time first. */
    STARTS_LATEST
}
