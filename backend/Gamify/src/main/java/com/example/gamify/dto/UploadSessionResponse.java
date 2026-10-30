package com.example.gamify.dto;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * Upload links for one post, in the order the files were asked for. Start every upload before
 * {@code expiresAt}, then commit the post with the keys.
 */
public record UploadSessionResponse(
        List<UploadTicketResponse> uploads,
        OffsetDateTime expiresAt
) {}
