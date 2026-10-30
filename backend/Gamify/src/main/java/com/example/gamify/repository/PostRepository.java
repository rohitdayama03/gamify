package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.Post;
import com.example.gamify.feed.PostScore;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface PostRepository extends JpaRepository<Post, Long> {

    // Newest first, older than beforeId
    @Query("SELECT p FROM Post p JOIN FETCH p.author WHERE p.author = :author AND p.id < :beforeId ORDER BY p.id DESC")
    List<Post> findByAuthorBefore(@Param("author") Player author, @Param("beforeId") Long beforeId, Pageable pageable);

    @Query("SELECT p FROM Post p JOIN FETCH p.author WHERE p.id = :id")
    Optional<Post> findWithAuthor(@Param("id") Long id);

    long countByAuthor(Player author);

    List<Post> findAllByAuthor(Player author);

    @Query("SELECT p FROM Post p JOIN FETCH p.author WHERE p.id IN :ids")
    List<Post> findAllWithAuthor(@Param("ids") Collection<Long> ids);

    // Counters change in the database, not on loaded entities, so two likes at once both count
    @Modifying
    @Query("UPDATE Post p SET p.likeCount = p.likeCount + :delta WHERE p.id = :postId")
    void addLikes(@Param("postId") Long postId, @Param("delta") int delta);

    @Modifying
    @Query("UPDATE Post p SET p.commentCount = p.commentCount + :delta WHERE p.id = :postId")
    void addComments(@Param("postId") Long postId, @Param("delta") int delta);

    // Recounts from the like and comment rows, e.g. after a player's likes and comments are deleted in bulk
    @Modifying
    @Query(value = """
            UPDATE posts p SET
                like_count = (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id),
                comment_count = (SELECT COUNT(*) FROM post_comments c WHERE c.post_id = p.id)
            WHERE p.id IN (:ids)
            """, nativeQuery = true)
    void recount(@Param("ids") Collection<Long> ids);

    // Fixes any counter that has drifted; returns how many were wrong
    @Modifying
    @Query(value = """
            UPDATE posts p SET like_count = x.likes, comment_count = x.comments
            FROM (SELECT q.id,
                         (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = q.id) AS likes,
                         (SELECT COUNT(*) FROM post_comments c WHERE c.post_id = q.id) AS comments
                  FROM posts q) x
            WHERE p.id = x.id AND (p.like_count <> x.likes OR p.comment_count <> x.comments)
            """, nativeQuery = true)
    int recountAll();

    /**
     * Rows of [postId, score] for the feed: the player's own posts and their friends', best first, scored at
     * [asOf] (see {@link PostScore}). Pages continue after the last row's score and id.
     * Posts made after [asOf] wait for the next refresh, so scrolling never meets them halfway down.
     */
    @Query(value = "SELECT id, score FROM (SELECT p.id, " + PostScore.SQL + " AS score" + """

                FROM posts p
                WHERE p.created_at <= CAST(:asOf AS timestamptz)
                  AND (p.author_id = :me OR p.author_id IN (
                        SELECT CASE WHEN c.sender_id = :me THEN c.receiver_id ELSE c.sender_id END
                        FROM player_connections c
                        WHERE c.status = 'ACCEPTED' AND (c.sender_id = :me OR c.receiver_id = :me)))
            ) ranked
            WHERE score < :afterScore OR (score = :afterScore AND id < :afterId)
            ORDER BY score DESC, id DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findFeedPage(@Param("me") Long me, @Param("asOf") OffsetDateTime asOf,
                                @Param("afterScore") double afterScore, @Param("afterId") long afterId,
                                @Param("limit") int limit);
}
