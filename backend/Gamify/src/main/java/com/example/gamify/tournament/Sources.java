package com.example.gamify.tournament;

/**
 * Where a fixture's player comes from, stored on the match until the player is known:
 * <ul>
 *   <li>{@code SLOT:3} — whoever is drawn into slot 3 when the tournament starts (first stage only)</li>
 *   <li>{@code GROUP:2:1} — the player finishing 1st in group 2 of the stage before</li>
 *   <li>{@code WINNER:1:2} / {@code LOSER:1:2} — the winner/loser of match 2 in round 1 of this knockout</li>
 * </ul>
 */
public final class Sources {

    private Sources() {}

    public static String slot(int slot) {
        return "SLOT:" + slot;
    }

    public static String group(int group, int rank) {
        return "GROUP:" + group + ":" + rank;
    }

    public static String winner(int round, int match) {
        return "WINNER:" + round + ":" + match;
    }

    public static String loser(int round, int match) {
        return "LOSER:" + round + ":" + match;
    }

    /** True when {@code source} takes the winner or loser of the given knockout match. */
    public static boolean feedsFrom(String source, int round, int match) {
        return source.equals(winner(round, match)) || source.equals(loser(round, match));
    }

    public static boolean isLoser(String source) {
        return source.startsWith("LOSER:");
    }

    /** "A" for group 1. */
    public static String groupLetter(int group) {
        return String.valueOf((char) ('A' + group - 1));
    }

    /**
     * A readable placeholder, e.g. "Slot 3", "Group B · 1st", "2nd place", "Winner of SF 1".
     *
     * @param previousGroups groups in the stage before (decides between "Group B · 1st" and "1st place")
     * @param knockoutEntrants players in this knockout stage (names the rounds)
     */
    public static String label(String source, int previousGroups, int knockoutEntrants) {
        String[] parts = source.split(":");
        return switch (parts[0]) {
            case "SLOT" -> "Slot " + parts[1];
            case "GROUP" -> previousGroups > 1
                    ? "Group " + groupLetter(Integer.parseInt(parts[1])) + " · " + ordinal(Integer.parseInt(parts[2]))
                    : ordinal(Integer.parseInt(parts[2])) + " place";
            case "WINNER", "LOSER" -> (parts[0].equals("WINNER") ? "Winner of " : "Loser of ")
                    + shortRoundName(knockoutEntrants, Integer.parseInt(parts[1])) + " " + parts[2];
            default -> source;
        };
    }

    /** "Final", "Semi-final", "Quarter-final", "Round of 16"… for round {@code round} of a knockout of {@code entrants}. */
    public static String roundName(int entrants, int round) {
        int matches = entrants >> round;
        return switch (matches) {
            case 1 -> "Final";
            case 2 -> "Semi-final";
            case 4 -> "Quarter-final";
            default -> "Round of " + matches * 2;
        };
    }

    public static String shortRoundName(int entrants, int round) {
        int matches = entrants >> round;
        return switch (matches) {
            case 1 -> "Final";
            case 2 -> "SF";
            case 4 -> "QF";
            default -> "R" + matches * 2;
        };
    }

    public static String ordinal(int n) {
        if (n % 100 >= 11 && n % 100 <= 13) {
            return n + "th";
        }
        return switch (n % 10) {
            case 1 -> n + "st";
            case 2 -> n + "nd";
            case 3 -> n + "rd";
            default -> n + "th";
        };
    }
}
