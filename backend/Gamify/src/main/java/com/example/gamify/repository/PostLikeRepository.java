package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.Post;
import com.example.gamify.entity.PostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface PostLikeRepository extends JpaRepository<PostLike, Long> {

    // 1 if the like was added, 0 if it was already there; two taps at once can't fail on the unique key
    @Modifying
    @Query(value = """
            INSERT INTO post_likes (post_id, player_id, created_at) VALUES (:postId, :playerId, now())
            ON CONFLICT (post_id, player_id) DO NOTHING
            """, nativeQuery = true)
    int insertIfAbsent(@Param("postId") Long postId, @Param("playerId") Long playerId);

    @Modifying
    @Query("DELETE FROM PostLike l WHERE l.post = :post AND l.player = :player")
    int deleteByPostAndPlayer(@Param("post") Post post, @Param("player") Player player);

    boolean existsByPostAndPlayer(Post post, Player player);

    long countByPost(Post post);

    // Which of these posts the player has liked
    @Query("SELECT l.post.id FROM PostLike l WHERE l.player = :player AND l.post.id IN :postIds")
    List<Long> findLikedPostIds(@Param("player") Player player, @Param("postIds") Collection<Long> postIds);

    @Modifying
    @Query("DELETE FROM PostLike l WHERE l.post = :post")
    void deleteAllOnPost(@Param("post") Post post);

    @Query("SELECT l.post.id FROM PostLike l WHERE l.player = :player")
    List<Long> findPostIdsLikedBy(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM PostLike l WHERE l.player = :player")
    void deleteAllByPlayer(@Param("player") Player player);
}
