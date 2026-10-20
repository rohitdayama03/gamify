package com.example.gamify.repository;

import com.example.gamify.entity.Player;
import com.example.gamify.entity.PlayerConnection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PlayerConnectionRepository extends JpaRepository<PlayerConnection, Long> {

    Optional<PlayerConnection> findBySenderAndReceiver(Player sender, Player receiver);

    // Every invite the player sent or received, with both players fetched to avoid N+1 queries
    @Query("""
            SELECT c FROM PlayerConnection c
            JOIN FETCH c.sender
            JOIN FETCH c.receiver
            WHERE c.sender = :player OR c.receiver = :player
            ORDER BY c.createdAt DESC
            """)
    List<PlayerConnection> findAllInvolving(@Param("player") Player player);

    @Query("""
            SELECT COUNT(c) > 0 FROM PlayerConnection c
            WHERE c.status = com.example.gamify.entity.ConnectionStatus.ACCEPTED
            AND ((c.sender = :a AND c.receiver = :b) OR (c.sender = :b AND c.receiver = :a))
            """)
    boolean areFriends(@Param("a") Player a, @Param("b") Player b);

    @Modifying
    @Query("DELETE FROM PlayerConnection c WHERE c.sender = :player OR c.receiver = :player")
    void deleteAllInvolving(@Param("player") Player player);
}
