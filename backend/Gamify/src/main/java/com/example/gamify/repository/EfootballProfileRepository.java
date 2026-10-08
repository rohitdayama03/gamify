package com.example.gamify.repository;

import com.example.gamify.entity.EfootballProfile;
import com.example.gamify.entity.Player;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface EfootballProfileRepository extends JpaRepository<EfootballProfile, Long> {

    Optional<EfootballProfile> findByPlayer(Player player);

    void deleteByPlayer(Player player);
}