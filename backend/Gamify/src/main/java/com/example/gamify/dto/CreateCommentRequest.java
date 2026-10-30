package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** {@code parentId} is the comment being replied to, or null for a new top-level comment. */
public record CreateCommentRequest(
        @NotBlank(message = "Write something first")
        @Size(max = 1000, message = "Comments can be at most 1000 characters")
        String content,
        Long parentId
) {}
