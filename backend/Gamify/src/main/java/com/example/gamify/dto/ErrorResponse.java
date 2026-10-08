package com.example.gamify.dto;

import java.time.OffsetDateTime;
import java.util.Map;

public record ErrorResponse(
        int status,
        String error,
        String message,
        String path,
        OffsetDateTime timestamp,
        Map<String, String> validationErrors
) {
    public ErrorResponse(int status, String error, String message, String path) {
        this(status, error, message, path, OffsetDateTime.now(), null);
    }

    public ErrorResponse(int status, String error, String message, String path, Map<String, String> validationErrors) {
        this(status, error, message, path, OffsetDateTime.now(), validationErrors);
    }
}