package com.example.gamify.repository;

import com.example.gamify.entity.GtaProfile;
import com.example.gamify.entity.Player;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface GtaProfileRepository extends JpaRepository<GtaProfile, Long> {

    Optional<GtaProfile> findByPlayer(Player player);

    void deleteByPlayer(Player player);
}
