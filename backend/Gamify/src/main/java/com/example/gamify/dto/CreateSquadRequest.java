package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

/** {@code memberIds} are friends to invite straight away; may be empty. */
public record CreateSquadRequest(
        @NotBlank(message = "Squad name is required")
        @Size(min = 3, max = 30, message = "Squad name must be 3 to 30 characters")
        @Pattern(regexp = "^[A-Za-z0-9 _-]+$", message = "Squad name can only use letters, numbers, spaces, - and _")
        String name,
        List<Long> memberIds
) {}
