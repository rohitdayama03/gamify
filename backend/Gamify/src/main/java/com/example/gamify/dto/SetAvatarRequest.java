package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;

/** {@code key} is from the upload ticket, once the picture is in S3. */
public record SetAvatarRequest(@NotBlank(message = "Upload the picture first") String key) {}
