package com.example.gamify.dto;

import com.example.gamify.media.UploadKind;

import java.util.Map;

/**
 * Where to upload one file: PUT the bytes to {@code uploadUrl} with exactly {@code headers} (and no login
 * token). Then pass {@code key} when committing the post.
 */
public record UploadTicketResponse(
        UploadKind kind,
        String key,
        String uploadUrl,
        String method,
        Map<String, String> headers
) {}
