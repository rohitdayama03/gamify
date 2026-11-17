package com.example.gamify.tournament;

import com.example.gamify.entity.StageType;
import com.example.gamify.exception.BadRequestException;

import java.util.ArrayList;
import java.util.List;

/**
 * Checks a tournament format and generates its fixtures, with placeholders ({@link Sources}) where players
 * aren't known yet. Pure logic, no database.
 * <p>
 * Players are dealt into league groups in turn (1st to group A, 2nd to group B, …), so group sizes differ by at
 * most one and the top seeds land in different groups. Players going through from a league are listed by rank
 * across groups (every group winner, then every runner-up, …), which is also their seeding for the next stage.
 */
public final class FormatPlanner {

    public static final int MIN_SLOTS = 2;
    public static final int MAX_SLOTS = 64;
    public static final int MAX_STAGES = 4;
    public static final int MAX_MATCHES = 1000;

    private FormatPlanner() {}

    public static List<PlannedStage> plan(int slots, List<StageSpec> stages) {
        if (slots < MIN_SLOTS || slots > MAX_SLOTS) {
            throw new BadRequestException("A tournament needs between " + MIN_SLOTS + " and " + MAX_SLOTS + " players");
        }
        if (stages == null || stages.isEmpty()) {
            throw new BadRequestException("Add at least one stage");
        }
        if (stages.size() > MAX_STAGES) {
            throw new BadRequestException("A tournament can have at most " + MAX_STAGES + " stages");
        }

        List<PlannedStage> planned = new ArrayList<>();
        List<String> entrants = new ArrayList<>();
        for (int slot = 1; slot <= slots; slot++) {
            entrants.add(Sources.slot(slot));
        }
        int totalMatches = 0;
        for (int i = 0; i < stages.size(); i++) {
            StageSpec spec = stages.get(i);
            int number = i + 1;
            boolean last = i == stages.size() - 1;
            if (spec == null || spec.type() == null) {
                throw new BadRequestException("Pick a type for stage " + number);
            }
            PlannedStage stage = spec.type() == StageType.LEAGUE
                    ? planLeague(spec, number, last, entrants)
                    : planKnockout(spec, number, last, entrants);
            planned.add(stage);
            totalMatches += stage.matches().size();
            if (!last) {
                entrants = qualifiers(stage.spec());
            }
        }
        if (totalMatches > MAX_MATCHES) {
            throw new BadRequestException("This format has " + totalMatches + " matches; keep it to " + MAX_MATCHES + " or fewer");
        }
        return planned;
    }

    private static PlannedStage planLeague(StageSpec spec, int number, boolean last, List<String> entrants) {
        String stage = "Stage " + number;
        int players = entrants.size();
        int groups = spec.groupCount();
        if (groups < 1) {
            throw new BadRequestException(stage + " needs at least 1 group");
        }
        if (players / groups < 2) {
            throw new BadRequestException(stage + " has " + players + " players, too few for " + groups + " groups of at least 2");
        }
        if (spec.rounds() != 1 && spec.rounds() != 2) {
            throw new BadRequestException(stage + ": players meet each other once or twice");
        }
        int advance = 0;
        if (last) {
            if (groups != 1) {
                throw new BadRequestException("The last stage needs a single group so there's one winner. Add a knockout after the groups, or use 1 group.");
            }
        } else {
            int smallestGroup = players / groups;
            advance = spec.advancePerGroup();
            if (advance < 1 || advance >= smallestGroup) {
                throw new BadRequestException(stage + ": between 1 and " + (smallestGroup - 1) + " players per group can go through");
            }
            if (groups * advance < 2) {
                throw new BadRequestException("At least 2 players must go through to stage " + (number + 1));
            }
        }

        List<List<String>> members = new ArrayList<>();
        for (int g = 0; g < groups; g++) {
            members.add(new ArrayList<>());
        }
        for (int k = 0; k < players; k++) {
            members.get(k % groups).add(entrants.get(k));
        }
        List<PlannedMatch> matches = new ArrayList<>();
        for (int g = 0; g < groups; g++) {
            matches.addAll(roundRobin(g + 1, members.get(g), spec.rounds()));
        }
        return new PlannedStage(new StageSpec(StageType.LEAGUE, groups, spec.rounds(), advance, false), players, matches);
    }

    private static PlannedStage planKnockout(StageSpec spec, int number, boolean last, List<String> entrants) {
        int players = entrants.size();
        if (!last) {
            throw new BadRequestException("A knockout has to be the last stage");
        }
        if (Integer.bitCount(players) != 1) {
            throw new BadRequestException("A knockout needs 2, 4, 8, 16, 32 or 64 players, but stage " + number + " would have " + players);
        }
        boolean thirdPlace = spec.thirdPlace();
        if (thirdPlace && players < 4) {
            throw new BadRequestException("A third-place match needs at least 4 players in the knockout");
        }

        List<PlannedMatch> matches = new ArrayList<>();
        int[] order = bracketOrder(players);
        for (int m = 1; m <= players / 2; m++) {
            matches.add(new PlannedMatch(null, 1, m, entrants.get(order[2 * m - 2] - 1), entrants.get(order[2 * m - 1] - 1)));
        }
        int rounds = Integer.numberOfTrailingZeros(players);
        for (int r = 2; r <= rounds; r++) {
            int count = players >> r;
            for (int m = 1; m <= count; m++) {
                matches.add(new PlannedMatch(null, r, m, Sources.winner(r - 1, 2 * m - 1), Sources.winner(r - 1, 2 * m)));
            }
        }
        if (thirdPlace) {
            matches.add(new PlannedMatch(null, rounds, 2, Sources.loser(rounds - 1, 1), Sources.loser(rounds - 1, 2)));
        }
        return new PlannedStage(new StageSpec(StageType.KNOCKOUT, 1, 1, 0, thirdPlace), players, matches);
    }

    /** Who goes through from a league stage, by rank across groups: every group winner, then every runner-up, … */
    private static List<String> qualifiers(StageSpec league) {
        List<String> next = new ArrayList<>();
        for (int rank = 1; rank <= league.advancePerGroup(); rank++) {
            for (int g = 1; g <= league.groupCount(); g++) {
                next.add(Sources.group(g, rank));
            }
        }
        return next;
    }

    /**
     * Seeds in bracket order, so that adjacent pairs are the first-round matches and seeds 1 and 2 can only meet
     * in the final: 8 → [1, 8, 4, 5, 2, 7, 3, 6].
     */
    static int[] bracketOrder(int players) {
        List<Integer> order = List.of(1);
        while (order.size() < players) {
            int size = order.size() * 2;
            List<Integer> next = new ArrayList<>();
            for (int seed : order) {
                next.add(seed);
                next.add(size + 1 - seed);
            }
            order = next;
        }
        return order.stream().mapToInt(Integer::intValue).toArray();
    }

    /** Circle method: one player stays put while the rest rotate, so everyone meets once per leg. */
    private static List<PlannedMatch> roundRobin(int group, List<String> players, int legs) {
        List<String> ring = new ArrayList<>(players);
        if (ring.size() % 2 == 1) {
            ring.add(null); // A bye: whoever draws it sits the round out
        }
        int n = ring.size();
        int roundsPerLeg = n - 1;
        List<PlannedMatch> firstLeg = new ArrayList<>();
        List<PlannedMatch> secondLeg = new ArrayList<>();
        for (int round = 1; round <= roundsPerLeg; round++) {
            int matchNo = 0;
            for (int i = 0; i < n / 2; i++) {
                String a = ring.get(i);
                String b = ring.get(n - 1 - i);
                if (a == null || b == null) {
                    continue;
                }
                // The fixed player would otherwise always be at home
                boolean swap = i == 0 && round % 2 == 0;
                String home = swap ? b : a;
                String away = swap ? a : b;
                matchNo++;
                firstLeg.add(new PlannedMatch(group, round, matchNo, home, away));
                if (legs == 2) {
                    secondLeg.add(new PlannedMatch(group, round + roundsPerLeg, matchNo, away, home));
                }
            }
            ring.add(1, ring.remove(n - 1));
        }
        firstLeg.addAll(secondLeg);
        return firstLeg;
    }
}
