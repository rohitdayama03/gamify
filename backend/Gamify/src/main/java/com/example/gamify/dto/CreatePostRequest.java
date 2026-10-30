package com.example.gamify.dto;

import com.example.gamify.entity.PostType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Commits a post once its files are uploaded. {@code mediaKey} is the uploaded image or video (none for text
 * posts); {@code thumbnailKey} an optional still for videos. Width and height are in pixels.
 */
public record CreatePostRequest(
        @NotNull(message = "Pick the post type") PostType type,
        @Size(max = 2200, message = "Posts can be at most 2200 characters") String text,
        String mediaKey,
        String thumbnailKey,
        Integer width,
        Integer height
) {}
