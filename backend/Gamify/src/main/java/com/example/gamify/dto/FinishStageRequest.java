package com.example.gamify.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Optional. For a league stage, the organizer's order for a group whose players are level on every tiebreaker:
 * the group's participant ids, 1st first. Only level players may swap places.
 */
public record FinishStageRequest(List<@Valid @NotNull GroupOrder> groupOrders) {
    public record GroupOrder(@NotNull Integer groupNo, @NotEmpty List<Long> participantIds) {}
}
