package com.example.gamify.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record GtaProfileResponse(
        Long id,
        String characterName,
        String platform,
        List<String> activities,
        Integer rank,
        OffsetDateTime updatedAt
) {}
