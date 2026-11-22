package com.example.gamify.tournament;

import java.util.*;

/**
 * League table maths, with the points for a win, draw and loss set per tournament ({@link Points}).
 * Players are ranked by points, then goal difference, then goals scored, then the same three counted only over
 * the matches between the players still level. Players level on all of that share a {@code tieBlock}; the
 * organizer settles their order when finishing the stage.
 */
public final class Standings {

    /** Points for a win, a draw and a loss. A loss may cost points (negative). */
    public record Points(int win, int draw, int loss) {
        /** What a tournament gets when its organizer doesn't choose. */
        public static final Points DEFAULT = new Points(3, 1, 0);
        /** Tournaments created before points could be chosen were scored this way, and keep it. */
        public static final Points LEGACY = new Points(2, 1, 0);
    }

    private Standings() {}

    public record Result(long homeId, long awayId, int homeScore, int awayScore) {}

    /** {@code tieBlock} is the index of the first row this row is level with (its own index when it isn't level). */
    public record Row(long participantId, int played, int won, int drawn, int lost,
                      int goalsFor, int goalsAgainst, int points, int tieBlock) {
        public int goalDifference() {
            return goalsFor - goalsAgainst;
        }
    }

    /**
     * Ranks {@code participants} (in seed order, which decides the display order of players fully level) on the
     * results between them. Results involving anyone else are ignored.
     */
    public static List<Row> rank(List<Long> participants, List<Result> results, Points points) {
        Map<Long, Tally> table = tally(participants, results, points);
        List<Tally> sorted = new ArrayList<>(table.values());
        Comparator<Tally> main = Comparator.<Tally>comparingInt(t -> t.points)
                .thenComparingInt(t -> t.goalsFor - t.goalsAgainst)
                .thenComparingInt(t -> t.goalsFor)
                .reversed();
        sorted.sort(main);

        int[] blocks = new int[sorted.size()];
        int start = 0;
        while (start < sorted.size()) {
            int end = start + 1;
            while (end < sorted.size() && main.compare(sorted.get(start), sorted.get(end)) == 0) {
                end++;
            }
            if (end - start == 1) {
                blocks[start] = start;
            } else {
                headToHead(sorted, start, end, results, points, blocks);
            }
            start = end;
        }

        List<Row> rows = new ArrayList<>();
        for (int i = 0; i < sorted.size(); i++) {
            Tally t = sorted.get(i);
            rows.add(new Row(t.id, t.played, t.won, t.drawn, t.lost, t.goalsFor, t.goalsAgainst, t.points, blocks[i]));
        }
        return rows;
    }

    /** True when another row shares this row's tie block. */
    public static boolean isTied(List<Row> rows, int index) {
        int block = rows.get(index).tieBlock();
        return (index > 0 && rows.get(index - 1).tieBlock() == block)
                || (index + 1 < rows.size() && rows.get(index + 1).tieBlock() == block);
    }

    // Re-sorts sorted[start, end) — players level on the main key — by their results against each other
    private static void headToHead(List<Tally> sorted, int start, int end, List<Result> results, Points points, int[] blocks) {
        List<Tally> level = sorted.subList(start, end);
        Map<Long, Tally> mini = tally(level.stream().map(t -> t.id).toList(), results, points);
        Comparator<Tally> byMini = Comparator.<Tally>comparingInt(t -> mini.get(t.id).points)
                .thenComparingInt(t -> mini.get(t.id).goalsFor - mini.get(t.id).goalsAgainst)
                .thenComparingInt(t -> mini.get(t.id).goalsFor)
                .reversed();
        level.sort(byMini);
        for (int i = start; i < end; i++) {
            blocks[i] = i > start && byMini.compare(sorted.get(i - 1), sorted.get(i)) == 0 ? blocks[i - 1] : i;
        }
    }

    private static Map<Long, Tally> tally(List<Long> participants, List<Result> results, Points points) {
        Map<Long, Tally> table = new LinkedHashMap<>();
        for (Long id : participants) {
            table.put(id, new Tally(id));
        }
        for (Result r : results) {
            Tally home = table.get(r.homeId());
            Tally away = table.get(r.awayId());
            if (home == null || away == null) {
                continue;
            }
            home.add(r.homeScore(), r.awayScore(), points);
            away.add(r.awayScore(), r.homeScore(), points);
        }
        return table;
    }

    private static final class Tally {
        final long id;
        int played, won, drawn, lost, goalsFor, goalsAgainst, points;

        Tally(long id) {
            this.id = id;
        }

        void add(int scored, int conceded, Points scoring) {
            played++;
            goalsFor += scored;
            goalsAgainst += conceded;
            if (scored > conceded) {
                won++;
                points += scoring.win();
            } else if (scored == conceded) {
                drawn++;
                points += scoring.draw();
            } else {
                lost++;
                points += scoring.loss();
            }
        }
    }
}
