package com.example.gamify.media;

import java.util.Arrays;
import java.util.Optional;

/** File types posts may contain, recognised from their first bytes rather than the name the phone sent. */
public enum MediaType {
    JPEG("jpg", "image/jpeg", false),
    PNG("png", "image/png", false),
    WEBP("webp", "image/webp", false),
    MP4("mp4", "video/mp4", true),
    MOV("mov", "video/quicktime", true);

    private final String extension;
    private final String contentType;
    private final boolean video;

    MediaType(String extension, String contentType, boolean video) {
        this.extension = extension;
        this.contentType = contentType;
        this.video = video;
    }

    public String extension() {
        return extension;
    }

    public String contentType() {
        return contentType;
    }

    public boolean isVideo() {
        return video;
    }

    public static Optional<MediaType> fromContentType(String contentType) {
        return Arrays.stream(values()).filter(t -> t.contentType.equalsIgnoreCase(contentType)).findFirst();
    }

    /** Recognises the type from a file's first 12 bytes, or empty when it's not a supported image or video. */
    public static Optional<MediaType> detect(byte[] head) {
        if (head.length >= 3 && (head[0] & 0xFF) == 0xFF && (head[1] & 0xFF) == 0xD8 && (head[2] & 0xFF) == 0xFF) {
            return Optional.of(JPEG);
        }
        if (head.length >= 8 && (head[0] & 0xFF) == 0x89 && head[1] == 'P' && head[2] == 'N' && head[3] == 'G') {
            return Optional.of(PNG);
        }
        if (head.length >= 12 && ascii(head, 0, 4).equals("RIFF") && ascii(head, 8, 4).equals("WEBP")) {
            return Optional.of(WEBP);
        }
        // ISO base media files (MP4, MOV) have an "ftyp" box at byte 4 followed by a brand
        if (head.length >= 12 && ascii(head, 4, 4).equals("ftyp")) {
            return Optional.of(ascii(head, 8, 4).equals("qt  ") ? MOV : MP4);
        }
        return Optional.empty();
    }

    private static String ascii(byte[] bytes, int offset, int length) {
        return new String(bytes, offset, length, java.nio.charset.StandardCharsets.US_ASCII);
    }
}
