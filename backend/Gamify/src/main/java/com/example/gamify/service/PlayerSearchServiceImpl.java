package com.example.gamify.service;

import com.example.gamify.dto.PlayerResponse;
import com.example.gamify.entity.Player;
import com.example.gamify.mapper.PlayerMapper;
import com.example.gamify.repository.PlayerRepository;
import com.example.gamify.repository.PlayerSpecification;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PlayerSearchServiceImpl implements PlayerSearchService {

    private final PlayerRepository playerRepository;
    private final PlayerMapper playerMapper;

    @Override
    @Transactional(readOnly = true)
    public Page<PlayerResponse> searchPlayers(
            String username,
            String country,
            String language,
            String bgmiRole,
            String efootballTier,
            Pageable pageable) {

        Specification<Player> spec = PlayerSpecification.filterPlayers(
                username, country, language, bgmiRole, efootballTier
        );

        Page<Player> playersPage = playerRepository.findAll(spec, pageable);

        return playersPage.map(playerMapper::toPlayerResponse);
    }
}