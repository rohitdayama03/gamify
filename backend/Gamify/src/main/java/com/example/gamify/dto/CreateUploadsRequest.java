package com.example.gamify.dto;

import com.example.gamify.media.UploadKind;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.util.List;

/**
 * Starts posting: the files one post needs, each with its exact size in bytes. That's one IMAGE or VIDEO,
 * plus an optional THUMBNAIL for a video.
 */
public record CreateUploadsRequest(
        @NotEmpty(message = "Add the file to upload")
        @Size(max = 2, message = "A post has one photo or video, plus a thumbnail for videos")
        List<@Valid File> files
) {
    public record File(
            @NotNull(message = "Say what the upload is for") UploadKind kind,
            @NotBlank(message = "Content type is required") String contentType,
            @NotNull @Positive(message = "The file is empty") Long size
    ) {}
}
