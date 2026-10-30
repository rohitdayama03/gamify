package com.example.gamify.media;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.util.unit.DataSize;

import java.time.Duration;

/**
 * Post media lives in a private S3 bucket. The app uploads straight to S3 with signed links and then asks
 * the backend to commit the post; the backend only keeps the object keys. A player posts one thing at a
 * time: links handed out within {@code uploadUrlExpiry} count as a post still uploading.
 *
 * @param maxImageSize      largest photo
 * @param maxVideoSize      largest video
 * @param maxThumbnailSize  largest video thumbnail
 * @param uploadUrlExpiry   how long a signed upload link works
 * @param pendingUploadTtl  how long an upload may wait to be committed before it's deleted
 */
@ConfigurationProperties(prefix = "app.media")
public record MediaProperties(
        DataSize maxImageSize,
        DataSize maxVideoSize,
        DataSize maxThumbnailSize,
        DataSize maxAvatarSize,
        Duration uploadUrlExpiry,
        Duration pendingUploadTtl,
        S3 s3
) {
    /**
     * @param region    blank to use the SDK's default (AWS_REGION, or the EC2 instance's region)
     * @param endpoint  blank for AWS; set to point at an S3-compatible server, e.g. for local testing
     * @param prefix    folder in the bucket the files go in, e.g. "posts/"
     * @param urlExpiry how long the signed download links handed to the app stay valid
     */
    public record S3(String bucket, String region, String endpoint, String prefix, Duration urlExpiry) {}
}
