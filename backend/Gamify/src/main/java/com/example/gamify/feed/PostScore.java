package com.example.gamify.feed;

import java.time.Duration;
import java.time.OffsetDateTime;

/**
 * How the feed ranks a post:
 * <pre>score = 10·e^(−ageHours/24) + (3·comments + likes)·e^(−ageHours/72)</pre>
 * Every post starts with 10 points for being new, fading over about a day; its engagement (a comment is
 * worth three likes) fades more slowly, over about three days. The same formula is in {@link #SQL} for
 * ranking in the database; keep the two in step.
 */
public final class PostScore {

    // Postgres refuses exp() of anything below about −708, which a post a couple of years old would reach
    private static final double MAX_DECAY = 700;

    /** The score of the post row {@code p} at the {@code :asOf} parameter. */
    public static final String SQL = """
            (10 * exp(-LEAST(GREATEST(EXTRACT(EPOCH FROM (CAST(:asOf AS timestamptz) - p.created_at)), 0) / 3600 / 24, 700))
             + (3 * p.comment_count + p.like_count)
               * exp(-LEAST(GREATEST(EXTRACT(EPOCH FROM (CAST(:asOf AS timestamptz) - p.created_at)), 0) / 3600 / 72, 700)))""";

    private PostScore() {}

    public static long engagement(long likes, long comments) {
        return 3 * comments + likes;
    }

    public static double at(OffsetDateTime createdAt, long likes, long comments, OffsetDateTime at) {
        double ageHours = Math.max(Duration.between(createdAt, at).toMillis(), 0) / 3_600_000.0;
        return 10 * Math.exp(-Math.min(ageHours / 24, MAX_DECAY))
                + engagement(likes, comments) * Math.exp(-Math.min(ageHours / 72, MAX_DECAY));
    }
}
