package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/** The profile picture about to be uploaded: a square JPEG the app has already cropped. */
public record AvatarUploadRequest(
        @NotBlank(message = "Content type is required") String contentType,
        @NotNull @Positive(message = "The file is empty") Long size
) {}
