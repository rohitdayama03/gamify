package com.example.gamify.tournament;

import com.example.gamify.entity.StageType;
import com.example.gamify.exception.BadRequestException;
import org.junit.jupiter.api.Test;

import java.util.*;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

class FormatPlannerTest {

    private static StageSpec league(int groups, int rounds, int advance) {
        return new StageSpec(StageType.LEAGUE, groups, rounds, advance, false);
    }

    private static StageSpec knockout(boolean thirdPlace) {
        return new StageSpec(StageType.KNOCKOUT, 0, 0, 0, thirdPlace);
    }

    @Test
    void groupsThenKnockout() {
        List<PlannedStage> plan = FormatPlanner.plan(16, List.of(league(4, 1, 2), knockout(true)));

        PlannedStage groups = plan.get(0);
        assertEquals(16, groups.entrants());
        assertEquals(24, groups.matches().size()); // 4 groups x 6
        // Players are dealt in turn, so group A has slots 1, 5, 9, 13
        Set<String> groupA = groups.matches().stream().filter(m -> m.groupNo() == 1)
                .flatMap(m -> List.of(m.homeSource(), m.awaySource()).stream()).collect(Collectors.toSet());
        assertEquals(Set.of("SLOT:1", "SLOT:5", "SLOT:9", "SLOT:13"), groupA);

        PlannedStage ko = plan.get(1);
        assertEquals(8, ko.entrants());
        assertEquals(4 + 2 + 1 + 1, ko.matches().size());
        // Seeds: group winners A-D are 1-4, runners-up 5-8; seed 1 meets seed 8
        PlannedMatch qf1 = ko.matches().get(0);
        assertEquals("GROUP:1:1", qf1.homeSource());
        assertEquals("GROUP:4:2", qf1.awaySource());
        // Nobody meets their own group in the quarter-finals
        for (PlannedMatch m : ko.matches().subList(0, 4)) {
            assertNotEquals(m.homeSource().split(":")[1], m.awaySource().split(":")[1]);
        }
        PlannedMatch fin = ko.matches().stream().filter(m -> m.roundNo() == 3 && m.matchNo() == 1).findFirst().orElseThrow();
        assertEquals("WINNER:2:1", fin.homeSource());
        assertEquals("WINNER:2:2", fin.awaySource());
        PlannedMatch third = ko.matches().stream().filter(m -> m.roundNo() == 3 && m.matchNo() == 2).findFirst().orElseThrow();
        assertEquals("LOSER:2:1", third.homeSource());
        assertEquals("LOSER:2:2", third.awaySource());
    }

    @Test
    void leagueEveryoneMeetsOnceWithAnOddNumber() {
        PlannedStage stage = FormatPlanner.plan(5, List.of(league(1, 1, 0))).get(0);
        assertEquals(10, stage.matches().size());
        Set<Set<String>> pairs = new HashSet<>();
        for (PlannedMatch m : stage.matches()) {
            assertNotEquals(m.homeSource(), m.awaySource());
            assertTrue(pairs.add(Set.of(m.homeSource(), m.awaySource())), "Pair played twice");
        }
        // Nobody plays twice in a round
        Map<Integer, List<String>> byRound = new HashMap<>();
        for (PlannedMatch m : stage.matches()) {
            byRound.computeIfAbsent(m.roundNo(), k -> new ArrayList<>()).addAll(List.of(m.homeSource(), m.awaySource()));
        }
        byRound.values().forEach(players -> assertEquals(new HashSet<>(players).size(), players.size()));
    }

    @Test
    void homeAndAwayLeagueReversesTheSecondLeg() {
        PlannedStage stage = FormatPlanner.plan(4, List.of(league(1, 2, 0))).get(0);
        assertEquals(12, stage.matches().size());
        Set<String> fixtures = stage.matches().stream().map(m -> m.homeSource() + ">" + m.awaySource()).collect(Collectors.toSet());
        assertEquals(12, fixtures.size()); // every ordered pair once
        assertEquals(6, stage.matches().stream().mapToInt(PlannedMatch::roundNo).max().orElseThrow());
    }

    @Test
    void leagueThenPlayoffs() {
        List<PlannedStage> plan = FormatPlanner.plan(8, List.of(league(1, 1, 4), knockout(false)));
        PlannedStage ko = plan.get(1);
        assertEquals(3, ko.matches().size());
        assertEquals("GROUP:1:1", ko.matches().get(0).homeSource());
        assertEquals("GROUP:1:4", ko.matches().get(0).awaySource());
        assertEquals("GROUP:1:2", ko.matches().get(1).homeSource());
        assertEquals("GROUP:1:3", ko.matches().get(1).awaySource());
    }

    @Test
    void plainKnockoutSeedsOneAgainstLast() {
        assertArrayEquals(new int[]{1, 8, 4, 5, 2, 7, 3, 6}, FormatPlanner.bracketOrder(8));
        PlannedStage ko = FormatPlanner.plan(2, List.of(knockout(false))).get(0);
        assertEquals(1, ko.matches().size());
    }

    @Test
    void rejectsBadFormats() {
        assertBad("2, 4, 8", () -> FormatPlanner.plan(6, List.of(knockout(false))));
        assertBad("last stage", () -> FormatPlanner.plan(8, List.of(knockout(false), league(1, 1, 0))));
        assertBad("single group", () -> FormatPlanner.plan(8, List.of(league(2, 1, 0))));
        assertBad("between 1 and 3", () -> FormatPlanner.plan(8, List.of(league(2, 1, 4), knockout(false))));
        assertBad("would have 6", () -> FormatPlanner.plan(12, List.of(league(3, 1, 2), knockout(false))));
        assertBad("too few", () -> FormatPlanner.plan(4, List.of(league(3, 1, 0))));
        assertBad("third-place", () -> FormatPlanner.plan(2, List.of(knockout(true))));
        assertBad("At least 2", () -> FormatPlanner.plan(8, List.of(league(1, 1, 1), league(1, 1, 0))));
        assertBad("between 2 and 64", () -> FormatPlanner.plan(65, List.of(knockout(false))));
    }

    @Test
    void sourceLabels() {
        assertEquals("Slot 3", Sources.label("SLOT:3", 1, 0));
        assertEquals("Group B · 1st", Sources.label("GROUP:2:1", 4, 8));
        assertEquals("2nd place", Sources.label("GROUP:1:2", 1, 4));
        assertEquals("Winner of QF 2", Sources.label("WINNER:1:2", 4, 8));
        assertEquals("Loser of SF 1", Sources.label("LOSER:2:1", 4, 8));
        assertEquals("Round of 16", Sources.roundName(16, 1));
        assertEquals("Final", Sources.roundName(16, 4));
    }

    private static void assertBad(String expectedPart, Runnable plan) {
        BadRequestException e = assertThrows(BadRequestException.class, plan::run);
        assertTrue(e.getMessage().contains(expectedPart), e.getMessage());
    }
}
