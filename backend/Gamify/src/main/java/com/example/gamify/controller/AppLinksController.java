package com.example.gamify.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * Android's Digital Asset Links file. It tells Android that this site belongs to the Gamify app, so shared
 * tournament links (/t/42) open straight in the app instead of the browser. Android fetches it when the
 * app is installed or updated. Without fingerprints configured it returns 404 and links open the link page,
 * which still hands over to the app.
 */
@RestController
public class AppLinksController {

    private final String packageName;
    private final List<String> fingerprints;

    public AppLinksController(
            @Value("${app.android.package-name}") String packageName,
            @Value("${app.android.cert-fingerprints:}") String fingerprints) {
        this.packageName = packageName;
        this.fingerprints = Arrays.stream(fingerprints.split(","))
                .map(String::trim)
                .filter(f -> !f.isEmpty())
                .toList();
    }

    @GetMapping(value = "/.well-known/assetlinks.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<List<Map<String, Object>>> assetLinks() {
        if (fingerprints.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(List.of(Map.of(
                "relation", List.of("delegate_permission/common.handle_all_urls"),
                "target", Map.of(
                        "namespace", "android_app",
                        "package_name", packageName,
                        "sha256_cert_fingerprints", fingerprints
                )
        )));
    }
}
