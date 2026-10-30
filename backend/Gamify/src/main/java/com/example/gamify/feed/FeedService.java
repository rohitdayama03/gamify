package com.example.gamify.feed;

import com.example.gamify.dto.FeedItemResponse;
import com.example.gamify.dto.FeedPageResponse;
import com.example.gamify.entity.Game;
import com.example.gamify.entity.NewsItem;
import com.example.gamify.entity.Player;
import com.example.gamify.entity.Post;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.mapper.PostMapper;
import com.example.gamify.repository.NewsItemRepository;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.repository.PostLikeRepository;
import com.example.gamify.repository.PostRepository;
import com.example.gamify.service.NewsServiceImpl;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * The Home feed: the player's own posts and their friends', ranked by {@link PostScore}, with gaming news
 * worked in at fixed places. Three posts come first, then a news item, then four posts and a news item,
 * and so on (news at positions 4, 9, 14…). When either runs out the other fills its places.
 */
@Service
@RequiredArgsConstructor
public class FeedService {

    public static final int DEFAULT_PAGE_SIZE = 20;
    public static final int MAX_PAGE_SIZE = 50;

    private final PlayerRepository playerRepository;
    private final PostRepository postRepository;
    private final PostLikeRepository likeRepository;
    private final NewsItemRepository newsItemRepository;
    private final PostMapper postMapper;

    /** Zero-based: 3, 8, 13… */
    static boolean isNewsSlot(int position) {
        return position >= 3 && (position - 3) % 5 == 0;
    }

    /** A page of the feed; [cursor] is null for the first page, or the previous page's nextCursor. */
    @Transactional(readOnly = true)
    public FeedPageResponse getFeed(String username, String cursor, int size) {
        Player me = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
        FeedCursor from = cursor == null || cursor.isBlank() ? FeedCursor.start() : FeedCursor.decode(cursor);

        // One more of each than the page could use, to know whether either has more
        List<RankedPost> ranked = postRepository
                .findFeedPage(me.getPlayerId(), from.asOf(), from.postScore(), from.postId(), size + 1).stream()
                .map(row -> new RankedPost(((Number) row[0]).longValue(), ((Number) row[1]).doubleValue()))
                .toList();
        List<NewsItem> news = newsItemRepository.findForFeed(
                relevantGames(me), from.newsAt(), from.newsId(), PageRequest.of(0, size + 1));

        // Lay the page out slot by slot; a slot whose kind has run out takes the other kind
        List<Object> slots = new ArrayList<>();
        int postsUsed = 0;
        int newsUsed = 0;
        while (slots.size() < size) {
            boolean postsLeft = postsUsed < ranked.size();
            boolean newsLeft = newsUsed < news.size();
            if (!postsLeft && !newsLeft) {
                break;
            }
            boolean takeNews = isNewsSlot(from.position() + slots.size()) ? newsLeft : !postsLeft;
            slots.add(takeNews ? news.get(newsUsed++) : ranked.get(postsUsed++));
        }

        RankedPost lastPost = postsUsed == 0 ? null : ranked.get(postsUsed - 1);
        NewsItem lastNews = newsUsed == 0 ? null : news.get(newsUsed - 1);
        boolean more = postsUsed < ranked.size() || newsUsed < news.size();
        String next = !more ? null : from.after(slots.size(),
                lastPost == null ? null : lastPost.score(), lastPost == null ? null : lastPost.id(),
                lastNews == null ? null : lastNews.getPublishedAt(), lastNews == null ? null : lastNews.getId()).encode();

        return new FeedPageResponse(toItems(slots, me), next);
    }

    private List<FeedItemResponse> toItems(List<Object> slots, Player me) {
        List<Long> postIds = slots.stream().filter(RankedPost.class::isInstance).map(s -> ((RankedPost) s).id()).toList();
        Map<Long, Post> posts = postIds.isEmpty() ? Map.of() : postRepository.findAllWithAuthor(postIds).stream()
                .collect(Collectors.toMap(Post::getId, Function.identity()));
        Set<Long> liked = postIds.isEmpty() ? Set.of() : new HashSet<>(likeRepository.findLikedPostIds(me, postIds));

        List<FeedItemResponse> items = new ArrayList<>();
        for (Object slot : slots) {
            if (slot instanceof NewsItem item) {
                items.add(FeedItemResponse.of(NewsServiceImpl.toResponse(item)));
            } else if (slot instanceof RankedPost rp && posts.get(rp.id()) != null) {
                // A post deleted since it was ranked is simply left out
                items.add(FeedItemResponse.of(postMapper.toResponse(posts.get(rp.id()), me, liked.contains(rp.id()), rp.score())));
            }
        }
        return items;
    }

    // News about the games they play, plus general gaming news; everything if they haven't picked games
    private static Collection<Game> relevantGames(Player me) {
        List<Game> games = Game.split(me.getInterestedGames());
        return games.isEmpty() ? List.of(Game.values()) : games;
    }

    private record RankedPost(long id, double score) {}
}
