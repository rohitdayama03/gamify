package com.example.gamify.service;

import com.example.gamify.dto.NewsItemResponse;
import com.example.gamify.entity.Game;
import com.example.gamify.entity.NewsItem;
import com.example.gamify.news.FeedEntry;
import com.example.gamify.news.NewsProperties;
import com.example.gamify.news.RssFeedParser;
import com.example.gamify.repository.NewsItemRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Pattern;

@Slf4j
@Service
public class NewsServiceImpl implements NewsService {

    // Whether a headline is about one of our games. Tags stories from general feeds (IGN), and filters
    // game-specific searches, which also return articles that only mention the game in passing.
    // BGMI news often names its publisher or official tournaments instead of the game.
    private static final Map<Game, Pattern> GAME_KEYWORDS = Map.of(
            Game.GTA, Pattern.compile("\\bgta\\b|grand theft auto", Pattern.CASE_INSENSITIVE),
            Game.BGMI, Pattern.compile("\\bbgmi\\b|battlegrounds mobile|\\bpubg\\b|krafton india|\\b(bmic|bmps|bgis|bgms)\\b", Pattern.CASE_INSENSITIVE),
            Game.EFOOTBALL, Pattern.compile("\\be-?football\\b|\\bpes \\d", Pattern.CASE_INSENSITIVE)
    );

    private final NewsItemRepository newsItemRepository;
    private final RssFeedParser parser;
    private final NewsProperties properties;
    private final Random random = new Random();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();
    // The startup check and the daily schedule could overlap; only one pull runs at a time
    private final AtomicBoolean refreshing = new AtomicBoolean(false);

    public NewsServiceImpl(NewsItemRepository newsItemRepository, RssFeedParser parser, NewsProperties properties) {
        this.newsItemRepository = newsItemRepository;
        this.parser = parser;
        this.properties = properties;
    }

    @Override
    @Transactional(readOnly = true)
    public Page<NewsItemResponse> getNews(Pageable pageable) {
        return newsItemRepository.findAllByOrderByFetchedAtDescShuffleKeyAscIdDesc(pageable).map(NewsServiceImpl::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<OffsetDateTime> lastFetchTime() {
        return newsItemRepository.findLatestFetchTime();
    }

    // Not one transaction: downloading feeds can take a while, so only the database writes are transactional
    @Override
    public int refreshFeeds() {
        if (!refreshing.compareAndSet(false, true)) {
            log.info("News refresh already running; skipping");
            return 0;
        }
        try {
            // Download every feed of every source at the same time
            Map<NewsProperties.Feed, CompletableFuture<List<FeedEntry>>> downloads = new LinkedHashMap<>();
            for (NewsProperties.Source source : properties.sources()) {
                for (NewsProperties.Feed feed : source.feeds()) {
                    downloads.put(feed, fetch(feed.url()));
                }
            }
            CompletableFuture.allOf(downloads.values().toArray(CompletableFuture[]::new)).join();

            Set<String> allLinks = new HashSet<>();
            downloads.values().forEach(d -> d.join().forEach(entry -> allLinks.add(entry.link())));
            Set<String> existing = allLinks.isEmpty() ? Set.of() : newsItemRepository.findExistingLinks(allLinks);

            OffsetDateTime now = OffsetDateTime.now();
            List<NewsItem> batch = new ArrayList<>();
            Set<String> taken = new HashSet<>(existing);
            for (NewsProperties.Source source : properties.sources()) {
                List<NewsItem> picked = pickNew(source, downloads, taken, now);
                log.info("News source {}: {} new stories (limit {})", source.name(), picked.size(), source.dailyLimit());
                batch.addAll(picked);
            }

            // Mix the sources so one doesn't fill the top of the feed; the order is stored so paging stays stable
            Collections.shuffle(batch, random);
            for (int i = 0; i < batch.size(); i++) {
                batch.get(i).setShuffleKey(i);
            }
            newsItemRepository.saveAll(batch);

            int pruned = newsItemRepository.deletePublishedBefore(now.minusDays(properties.retentionDays()));
            log.info("News refresh: {} new stories saved, {} older than {} days removed", batch.size(), pruned, properties.retentionDays());
            return batch.size();
        } finally {
            refreshing.set(false);
        }
    }

    /**
     * Up to the source's daily limit of stories not stored yet, taken in turn from each of its feeds (newest
     * first), so a busy feed can't crowd out the others; e.g. Google News splits its 50 across BGMI, eFootball and GTA.
     */
    private List<NewsItem> pickNew(NewsProperties.Source source,
                                   Map<NewsProperties.Feed, CompletableFuture<List<FeedEntry>>> downloads,
                                   Set<String> taken, OffsetDateTime fetchedAt) {
        List<Deque<FeedEntry>> queues = new ArrayList<>();
        for (NewsProperties.Feed feed : source.feeds()) {
            queues.add(new ArrayDeque<>(downloads.get(feed).join().stream()
                    .sorted(Comparator.comparing(FeedEntry::publishedAt).reversed())
                    .toList()));
        }

        OffsetDateTime oldestKept = fetchedAt.minusDays(properties.retentionDays());
        List<NewsItem> picked = new ArrayList<>();
        boolean progress = true;
        while (picked.size() < source.dailyLimit() && progress) {
            progress = false;
            for (int i = 0; i < queues.size() && picked.size() < source.dailyLimit(); i++) {
                NewsProperties.Feed feed = source.feeds().get(i);
                FeedEntry entry;
                while ((entry = queues.get(i).poll()) != null) {
                    // A game-specific feed only contributes stories whose headline is actually about that game
                    if (feed.requiresTitleMatch() && !mentions(entry, feed.game())) {
                        continue;
                    }
                    // Would be pruned straight away (e.g. a channel's months-old videos on the first pull)
                    if (entry.publishedAt().isBefore(oldestKept)) {
                        continue;
                    }
                    if (taken.add(entry.link())) {
                        picked.add(toEntity(entry, source, feed, fetchedAt));
                        progress = true;
                        break;
                    }
                }
            }
        }
        return picked;
    }

    // One broken feed shouldn't stop the others, so failures are logged and give an empty list
    private CompletableFuture<List<FeedEntry>> fetch(String url) {
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(30))
                .header("User-Agent", "GamifyNewsBot/1.0")
                .header("Accept", "application/rss+xml, application/xml, text/xml")
                .GET()
                .build();
        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofByteArray())
                .thenApply(response -> {
                    if (response.statusCode() != 200) {
                        log.warn("News feed {} returned HTTP {}", url, response.statusCode());
                        return List.<FeedEntry>of();
                    }
                    try {
                        return parser.parse(response.body());
                    } catch (Exception e) {
                        log.warn("Could not parse news feed {}: {}", url, e.toString());
                        return List.<FeedEntry>of();
                    }
                })
                .exceptionally(e -> {
                    log.warn("Could not read news feed {}: {}", url, e.toString());
                    return List.of();
                });
    }

    private NewsItem toEntity(FeedEntry entry, NewsProperties.Source source, NewsProperties.Feed feed, OffsetDateTime fetchedAt) {
        return NewsItem.builder()
                .link(truncate(entry.link(), 1000))
                .title(truncate(entry.title(), 500))
                .summary(entry.summary())
                .imageUrl(truncate(entry.imageUrl(), 1000))
                .video(entry.video())
                .category(truncate(entry.category(), 200))
                .author(truncate(entry.author(), 200))
                // Credit the original publisher when the feed aggregates others
                .source(truncate(entry.publisher() != null ? entry.publisher() : source.name(), 100))
                .game(feed.game() != null ? feed.game() : detectGame(entry))
                .publishedAt(entry.publishedAt())
                .fetchedAt(fetchedAt)
                .build();
    }

    private static Game detectGame(FeedEntry entry) {
        return Arrays.stream(Game.values())
                .filter(game -> mentions(entry, game))
                .findFirst()
                .orElse(null);
    }

    private static boolean mentions(FeedEntry entry, Game game) {
        String text = Objects.toString(entry.category(), "") + " " + entry.title();
        return GAME_KEYWORDS.get(game).matcher(text).find();
    }

    private static String truncate(String value, int max) {
        return value == null || value.length() <= max ? value : value.substring(0, max);
    }

    private static NewsItemResponse toResponse(NewsItem item) {
        return new NewsItemResponse(
                item.getId(),
                item.getTitle(),
                item.getSummary(),
                item.getImageUrl(),
                Boolean.TRUE.equals(item.getVideo()),
                item.getLink(),
                item.getCategory(),
                item.getAuthor(),
                item.getSource(),
                item.getGame(),
                item.getPublishedAt()
        );
    }
}
