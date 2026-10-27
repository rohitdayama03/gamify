package com.example.gamify.controller;

import com.example.gamify.dto.DeviceTokenRequest;
import com.example.gamify.service.DeviceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceService deviceService;

    // Called by the app after login and whenever Firebase gives the phone a new token
    @PostMapping
    public ResponseEntity<Void> register(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody DeviceTokenRequest request) {
        deviceService.register(currentUsername, request.token(), request.platform());
        return ResponseEntity.noContent().build();
    }

    // Called by the app on logout, before the login token is discarded
    @PostMapping("/unregister")
    public ResponseEntity<Void> unregister(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody DeviceTokenRequest request) {
        deviceService.unregister(currentUsername, request.token());
        return ResponseEntity.noContent().build();
    }
}
