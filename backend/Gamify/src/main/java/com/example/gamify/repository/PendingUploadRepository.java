package com.example.gamify.repository;

import com.example.gamify.entity.PendingUpload;
import com.example.gamify.entity.Player;
import com.example.gamify.media.UploadKind;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface PendingUploadRepository extends JpaRepository<PendingUpload, Long> {

    List<PendingUpload> findAllByOwner(Player owner);

    // Profile pictures upload on their own, so a post's session is everything else
    @Query("SELECT u FROM PendingUpload u WHERE u.owner = :owner AND u.kind <> com.example.gamify.media.UploadKind.AVATAR")
    List<PendingUpload> findPostUploads(@Param("owner") Player owner);

    List<PendingUpload> findAllByOwnerAndKind(Player owner, UploadKind kind);

    // Post uploads whose links were handed out after [since], i.e. a post that may still be uploading
    @Query("""
            SELECT COUNT(u) > 0 FROM PendingUpload u
            WHERE u.owner = :owner AND u.createdAt > :since AND u.kind <> com.example.gamify.media.UploadKind.AVATAR
            """)
    boolean existsStartedAfter(@Param("owner") Player owner, @Param("since") OffsetDateTime since);

    @Query("SELECT u FROM PendingUpload u WHERE u.expiresAt <= :now ORDER BY u.expiresAt ASC")
    List<PendingUpload> findExpired(@Param("now") OffsetDateTime now, Pageable pageable);
}
