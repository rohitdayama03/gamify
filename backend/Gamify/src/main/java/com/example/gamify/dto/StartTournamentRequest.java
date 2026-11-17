package com.example.gamify.dto;

import jakarta.validation.constraints.NotNull;

import java.util.List;

/** RANDOM shuffles the players into slots; MANUAL puts {@code order} (participant ids, slot 1 first) in place. */
public record StartTournamentRequest(
        @NotNull(message = "Pick how to seed the players") Seeding seeding,
        List<Long> order
) {
    public enum Seeding { RANDOM, MANUAL }
}
