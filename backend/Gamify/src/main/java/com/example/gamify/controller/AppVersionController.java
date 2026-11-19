package com.example.gamify.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * The oldest Android version code still allowed to use the app. Older installs are made to update before
 * they can continue. Public, because the app checks it before anyone signs in.
 */
@RestController
@RequestMapping("/api/v1/app")
public class AppVersionController {

    public record AppVersionResponse(int minAndroidVersionCode) {}

    private final int minAndroidVersionCode;

    public AppVersionController(@Value("${app.android.min-version-code:0}") int minAndroidVersionCode) {
        this.minAndroidVersionCode = minAndroidVersionCode;
    }

    @GetMapping("/version")
    public ResponseEntity<AppVersionResponse> version() {
        return ResponseEntity.ok(new AppVersionResponse(minAndroidVersionCode));
    }
}
