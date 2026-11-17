package com.example.gamify.tournament;

import com.example.gamify.entity.StageType;

/** A stage as the organizer designed it. League fields are ignored for a knockout and vice versa. */
public record StageSpec(StageType type, int groupCount, int rounds, int advancePerGroup, boolean thirdPlace) {}
