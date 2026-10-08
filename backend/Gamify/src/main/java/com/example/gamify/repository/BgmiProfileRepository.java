package com.example.gamify.repository;

import com.example.gamify.entity.BgmiProfile;
import com.example.gamify.entity.Player;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BgmiProfileRepository extends JpaRepository<BgmiProfile, Long> {

    Optional<BgmiProfile> findByPlayer(Player player);

    void deleteByPlayer(Player player);
}