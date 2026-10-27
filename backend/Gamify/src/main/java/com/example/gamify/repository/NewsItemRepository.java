package com.example.gamify.repository;

import com.example.gamify.entity.NewsItem;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.Optional;
import java.util.Set;

@Repository
public interface NewsItemRepository extends JpaRepository<NewsItem, Long> {

    // Newest pull first, mixed within each pull; id breaks any remaining ties so paging is stable
    Page<NewsItem> findAllByOrderByFetchedAtDescShuffleKeyAscIdDesc(Pageable pageable);

    @Query("SELECT n.link FROM NewsItem n WHERE n.link IN :links")
    Set<String> findExistingLinks(@Param("links") Collection<String> links);

    @Query("SELECT MAX(n.fetchedAt) FROM NewsItem n")
    Optional<OffsetDateTime> findLatestFetchTime();

    @Transactional
    @Modifying
    @Query("DELETE FROM NewsItem n WHERE n.publishedAt < :cutoff")
    int deletePublishedBefore(@Param("cutoff") OffsetDateTime cutoff);
}
