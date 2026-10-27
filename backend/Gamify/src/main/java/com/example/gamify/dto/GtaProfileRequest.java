package com.example.gamify.dto;

import jakarta.validation.constraints.*;

import java.util.List;

public record GtaProfileRequest(
        @NotBlank @Size(max = 50) String characterName,
        @NotBlank @Pattern(regexp = "PlayStation|PC", message = "Choose PlayStation or PC") String platform,
        @Size(max = 4) List<@Pattern(regexp = "Heist|Free roam|Racing|Casual mission", message = "Unknown activity") String> activities,
        @Min(value = 1, message = "Rank must be between 1 and 100")
        @Max(value = 100, message = "Rank must be between 1 and 100")
        Integer rank
) {}
