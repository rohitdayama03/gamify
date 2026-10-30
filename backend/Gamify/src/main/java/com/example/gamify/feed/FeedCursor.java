package com.example.gamify.feed;

import com.example.gamify.exception.BadRequestException;

import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Base64;

/**
 * Where the next feed page starts, handed to the app as an opaque string.
 *
 * @param asOf      when the first page was made; posts are scored as of then on every page, so their order
 *                  can't shift while the player scrolls
 * @param position  how many items came before, which decides where the next news item goes
 * @param postScore the last post shown's score and id; the next posts rank below them
 * @param newsAt    the last news item shown's publish time and id; the next news is older
 */
public record FeedCursor(OffsetDateTime asOf, int position, double postScore, long postId,
                         OffsetDateTime newsAt, long newsId) {

    // Later than any news item, so the first page starts from the newest
    private static final OffsetDateTime NEWEST = OffsetDateTime.of(9999, 1, 1, 0, 0, 0, 0, ZoneOffset.UTC);

    private static final String VERSION = "1";

    public static FeedCursor start() {
        // Whole milliseconds, so it reads back exactly from the cursor and later pages score the same way
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.MILLIS);
        return new FeedCursor(now, 0, Double.POSITIVE_INFINITY, Long.MAX_VALUE, NEWEST, Long.MAX_VALUE);
    }

    public FeedCursor after(int shown, Double lastScore, Long lastPostId, OffsetDateTime lastNewsAt, Long lastNewsId) {
        return new FeedCursor(asOf, position + shown,
                lastPostId == null ? postScore : lastScore, lastPostId == null ? postId : lastPostId,
                lastNewsId == null ? newsAt : lastNewsAt, lastNewsId == null ? newsId : lastNewsId);
    }

    public String encode() {
        String text = String.join("|", VERSION, asOf.toString(), Integer.toString(position),
                Double.toString(postScore), Long.toString(postId), newsAt.toString(), Long.toString(newsId));
        return Base64.getUrlEncoder().withoutPadding().encodeToString(text.getBytes(StandardCharsets.UTF_8));
    }

    public static FeedCursor decode(String cursor) {
        try {
            String[] parts = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8).split("\\|");
            if (parts.length != 7 || !VERSION.equals(parts[0])) {
                throw new IllegalArgumentException("Unknown cursor");
            }
            return new FeedCursor(OffsetDateTime.parse(parts[1]), Integer.parseInt(parts[2]),
                    Double.parseDouble(parts[3]), Long.parseLong(parts[4]),
                    OffsetDateTime.parse(parts[5]), Long.parseLong(parts[6]));
        } catch (RuntimeException e) {
            throw new BadRequestException("This feed page has expired. Pull down to refresh.");
        }
    }
}
