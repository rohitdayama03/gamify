package com.example.gamify.service;

import com.example.gamify.entity.DeviceToken;
import com.example.gamify.entity.Player;
import com.example.gamify.exception.ResourceNotFoundException;
import com.example.gamify.repository.DeviceTokenRepository;
import com.example.gamify.repository.PlayerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DeviceServiceImpl implements DeviceService {

    private final PlayerRepository playerRepository;
    private final DeviceTokenRepository deviceTokenRepository;

    @Override
    @Transactional
    public void register(String username, String token, String platform) {
        Player player = playerRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Player not found with username: " + username));
        // A token belongs to one phone; if someone else was signed in on it, notifications now go to this player
        DeviceToken device = deviceTokenRepository.findByToken(token)
                .orElseGet(() -> DeviceToken.builder().token(token).build());
        device.setPlayer(player);
        device.setPlatform(platform);
        deviceTokenRepository.save(device);
    }

    @Override
    @Transactional
    public void unregister(String username, String token) {
        deviceTokenRepository.findByToken(token)
                .filter(device -> device.getPlayer().getUsername().equals(username))
                .ifPresent(deviceTokenRepository::delete);
    }
}
