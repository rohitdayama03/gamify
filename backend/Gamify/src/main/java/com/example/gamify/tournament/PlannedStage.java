package com.example.gamify.tournament;

import java.util.List;

/** A checked stage with how many players it has and its fixtures. League fields are normalized (0 when unused). */
public record PlannedStage(StageSpec spec, int entrants, List<PlannedMatch> matches) {}
