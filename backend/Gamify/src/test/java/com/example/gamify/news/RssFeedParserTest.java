package com.example.gamify.news;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class RssFeedParserTest {

    private final RssFeedParser parser = new RssFeedParser();

    // Shaped like IGN India's feed: HTML-escaped description with an <img>, an image enclosure, dc:creator
    private static final String FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
              <channel>
                <title>IGN India</title>
                <item>
                  <title>GTA 6 Trailer &amp; Release Date</title>
                  <link>https://in.ign.com/gta-6/1/gta-6-trailer</link>
                  <description>&lt;img src="https://sm.ign.com/small.jpg" width="120" /&gt;Rockstar &lt;b&gt;finally&lt;/b&gt; shares   more.</description>
                  <category>Grand Theft Auto VI</category>
                  <dc:creator>Jane Doe</dc:creator>
                  <enclosure url="https://sm.ign.com/full.jpg" type="image/jpeg" length="0" />
                  <pubDate>Tue, 27 Oct 2026 20:28:06 +0000</pubDate>
                </item>
                <item>
                  <title>No image here</title>
                  <link>https://in.ign.com/x/2/no-image</link>
                  <description>&lt;img src="https://sm.ign.com/only-in-description.jpg" /&gt;Text</description>
                  <pubDate>Mon, 26 Oct 2026 08:00:00 +0000</pubDate>
                </item>
                <item>
                  <title>Missing date is skipped</title>
                  <link>https://in.ign.com/x/3/no-date</link>
                </item>
              </channel>
            </rss>
            """;

    @Test
    void readsFieldsFromItems() throws Exception {
        List<FeedEntry> entries = parser.parse(FEED.getBytes(StandardCharsets.UTF_8));

        assertEquals(2, entries.size());
        FeedEntry first = entries.get(0);
        assertEquals("GTA 6 Trailer & Release Date", first.title());
        assertEquals("https://in.ign.com/gta-6/1/gta-6-trailer", first.link());
        assertEquals("Rockstar finally shares more.", first.summary());
        assertEquals("https://sm.ign.com/full.jpg", first.imageUrl());
        assertEquals("Grand Theft Auto VI", first.category());
        assertEquals("Jane Doe", first.author());
        assertEquals(OffsetDateTime.of(2026, 10, 27, 20, 28, 6, 0, ZoneOffset.UTC), first.publishedAt());
    }

    @Test
    void fallsBackToImageInDescription() throws Exception {
        FeedEntry second = parser.parse(FEED.getBytes(StandardCharsets.UTF_8)).get(1);
        assertEquals("https://sm.ign.com/only-in-description.jpg", second.imageUrl());
    }

    // Shaped like a Google News search feed: publisher in <source> and after " - " in the title,
    // and a description that only repeats the headline as a link
    private static final String GOOGLE_NEWS = """
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
              <channel>
                <item>
                  <title>BGMI 4.1 Update Brings New Map - The Times</title>
                  <link>https://news.google.com/rss/articles/abc</link>
                  <description>&lt;a href="https://news.google.com/rss/articles/abc"&gt;BGMI 4.1 Update Brings New Map&lt;/a&gt;&amp;nbsp;&amp;nbsp;&lt;font color="#6f6f6f"&gt;The Times&lt;/font&gt;</description>
                  <pubDate>Tue, 27 Oct 2026 10:00:00 GMT</pubDate>
                  <source url="https://thetimes.example">The Times</source>
                </item>
              </channel>
            </rss>
            """;

    @Test
    void readsAggregatorItems() throws Exception {
        FeedEntry entry = parser.parse(GOOGLE_NEWS.getBytes(StandardCharsets.UTF_8)).get(0);
        assertEquals("BGMI 4.1 Update Brings New Map", entry.title());
        assertEquals("The Times", entry.publisher());
        assertNull(entry.summary(), "a repeated headline is not a teaser");
        assertNull(entry.imageUrl());
    }

    // Shaped like a YouTube channel feed (Atom with media:group)
    private static final String YOUTUBE = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/" xmlns="http://www.w3.org/2005/Atom">
              <title>KRAFTON INDIA ESPORTS</title>
              <entry>
                <id>yt:video:abc123</id>
                <title>BMIC 2026 | Grand Finals Day 1</title>
                <link rel="alternate" href="https://www.youtube.com/watch?v=abc123"/>
                <author><name>KRAFTON INDIA ESPORTS</name></author>
                <published>2026-10-27T12:30:00+00:00</published>
                <media:group>
                  <media:title>BMIC 2026 | Grand Finals Day 1</media:title>
                  <media:thumbnail url="https://i4.ytimg.com/vi/abc123/hqdefault.jpg" width="480" height="360"/>
                  <media:description>Watch the best BGMI teams battle it out.</media:description>
                </media:group>
              </entry>
            </feed>
            """;

    @Test
    void readsYouTubeVideos() throws Exception {
        List<FeedEntry> entries = parser.parse(YOUTUBE.getBytes(StandardCharsets.UTF_8));
        assertEquals(1, entries.size());
        FeedEntry video = entries.get(0);
        assertTrue(video.video());
        assertEquals("BMIC 2026 | Grand Finals Day 1", video.title());
        assertEquals("https://www.youtube.com/watch?v=abc123", video.link());
        assertEquals("https://i4.ytimg.com/vi/abc123/hqdefault.jpg", video.imageUrl());
        assertEquals("KRAFTON INDIA ESPORTS", video.publisher());
        assertEquals("Watch the best BGMI teams battle it out.", video.summary());
        assertEquals(OffsetDateTime.of(2026, 10, 27, 12, 30, 0, 0, ZoneOffset.UTC), video.publishedAt());
    }

    @Test
    void rejectsExternalEntities() {
        String xxe = """
                <?xml version="1.0"?>
                <!DOCTYPE rss [<!ENTITY secret SYSTEM "file:///etc/passwd">]>
                <rss><channel><item><title>&secret;</title></item></channel></rss>
                """;
        assertThrows(Exception.class, () -> parser.parse(xxe.getBytes(StandardCharsets.UTF_8)));
    }
}
