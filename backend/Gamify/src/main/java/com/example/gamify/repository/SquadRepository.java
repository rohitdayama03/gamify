package com.example.gamify.repository;

import com.example.gamify.entity.Squad;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SquadRepository extends JpaRepository<Squad, Long> {

    boolean existsByNameKey(String nameKey);
}
