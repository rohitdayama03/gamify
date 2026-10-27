package com.example.gamify.repository;

import com.example.gamify.entity.DeviceToken;
import com.example.gamify.entity.Player;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {

    Optional<DeviceToken> findByToken(String token);

    @Query("SELECT d.token FROM DeviceToken d WHERE d.player.playerId = :playerId")
    List<String> findTokensByPlayerId(@Param("playerId") Long playerId);

    @Transactional
    @Modifying
    @Query("DELETE FROM DeviceToken d WHERE d.token IN :tokens")
    int deleteByTokens(@Param("tokens") Collection<String> tokens);

    @Modifying
    @Query("DELETE FROM DeviceToken d WHERE d.player = :player")
    void deleteAllByPlayer(@Param("player") Player player);
}
