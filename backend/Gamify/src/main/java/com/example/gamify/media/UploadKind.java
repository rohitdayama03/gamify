package com.example.gamify.media;

import java.util.Set;

/** What an upload is for, which decides the file types it may be. */
public enum UploadKind {
    IMAGE(Set.of(MediaType.JPEG, MediaType.PNG, MediaType.WEBP)),
    VIDEO(Set.of(MediaType.MP4, MediaType.MOV)),
    // A still frame of a video, made on the phone
    THUMBNAIL(Set.of(MediaType.JPEG)),
    // A profile picture, cropped square on the phone
    AVATAR(Set.of(MediaType.JPEG));

    private final Set<MediaType> allowed;

    UploadKind(Set<MediaType> allowed) {
        this.allowed = allowed;
    }

    public boolean allows(MediaType type) {
        return allowed.contains(type);
    }

    public long maxBytes(MediaProperties properties) {
        return switch (this) {
            case IMAGE -> properties.maxImageSize().toBytes();
            case VIDEO -> properties.maxVideoSize().toBytes();
            case THUMBNAIL -> properties.maxThumbnailSize().toBytes();
            case AVATAR -> properties.maxAvatarSize().toBytes();
        };
    }

    public String allowedDescription() {
        return switch (this) {
            case IMAGE -> "Images must be JPEG, PNG or WebP";
            case VIDEO -> "Videos must be MP4 or MOV";
            case THUMBNAIL -> "Video thumbnails must be JPEG";
            case AVATAR -> "Profile pictures must be JPEG";
        };
    }
}
