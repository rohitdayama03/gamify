package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.Post;
import com.example.gamify.entity.PostComment;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface PostCommentRepository extends JpaRepository<PostComment, Long> {

    // Top-level comments, oldest first, after afterId
    @Query("""
            SELECT c FROM PostComment c JOIN FETCH c.author
            WHERE c.post = :post AND c.parent IS NULL AND c.id > :afterId
            ORDER BY c.id ASC
            """)
    List<PostComment> findTopLevel(@Param("post") Post post, @Param("afterId") Long afterId, Pageable pageable);

    // Replies to the given comments, oldest first
    @Query("SELECT c FROM PostComment c JOIN FETCH c.author WHERE c.parent.id IN :parentIds ORDER BY c.id ASC")
    List<PostComment> findReplies(@Param("parentIds") Collection<Long> parentIds);

    // Posts the player commented on, or where someone replied to them
    @Query("SELECT DISTINCT c.post.id FROM PostComment c LEFT JOIN c.parent parent WHERE c.author = :player OR parent.author = :player")
    List<Long> findPostIdsInvolving(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM PostComment c WHERE c.parent = :parent")
    int deleteReplies(@Param("parent") PostComment parent);

    // Replies first so no reply is left pointing at a deleted comment
    @Modifying
    @Query("DELETE FROM PostComment c WHERE c.post = :post AND c.parent IS NOT NULL")
    void deleteRepliesOnPost(@Param("post") Post post);

    @Modifying
    @Query("DELETE FROM PostComment c WHERE c.post = :post")
    void deleteAllOnPost(@Param("post") Post post);

    // Replies anyone wrote under the player's top-level comments
    @Modifying
    @Query("DELETE FROM PostComment c WHERE c.parent IN (SELECT p FROM PostComment p WHERE p.author = :player)")
    void deleteRepliesToAuthor(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM PostComment c WHERE c.author = :player AND c.parent IS NOT NULL")
    void deleteRepliesByAuthor(@Param("player") Player player);

    @Modifying
    @Query("DELETE FROM PostComment c WHERE c.author = :player")
    void deleteAllByAuthor(@Param("player") Player player);
}
