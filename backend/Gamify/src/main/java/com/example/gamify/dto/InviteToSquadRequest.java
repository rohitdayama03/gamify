package com.example.gamify.dto;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record InviteToSquadRequest(
        @NotEmpty(message = "Pick at least one friend to invite") List<Long> playerIds
) {}
