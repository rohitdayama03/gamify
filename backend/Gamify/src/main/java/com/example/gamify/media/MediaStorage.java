package com.example.gamify.media;

import lombok.extern.slf4j.Slf4j;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Post photos and videos in a private S3 bucket. Files are uploaded by the app through signed PUT links and
 * read through signed GET links, so media bytes never pass through this server; this class only signs links,
 * inspects uploaded objects and deletes them.
 */
@Slf4j
public class MediaStorage {

    // Only keys this class generates
    private static final Pattern KEY = Pattern.compile("^[0-9a-f]{32}\\.(jpg|png|webp|mp4|mov)$");

    // A key's file never changes, so phones may cache it for as long as they like
    private static final String CACHE_CONTROL = "private, max-age=31536000, immutable";

    /** A signed upload: PUT the file to {@code url} with exactly these {@code headers}. */
    public record PresignedUpload(String url, Map<String, String> headers, Instant expiresAt) {}

    private final S3Client s3;
    private final S3Presigner presigner;
    private final String bucket;
    private final String prefix;
    private final Duration downloadUrlExpiry;

    public MediaStorage(S3Client s3, S3Presigner presigner, String bucket, String prefix, Duration downloadUrlExpiry) {
        this.s3 = s3;
        this.presigner = presigner;
        this.bucket = bucket;
        this.prefix = prefix == null ? "" : prefix;
        this.downloadUrlExpiry = downloadUrlExpiry;
        // Fail at startup, not on the first upload, if the bucket is missing or this server can't reach it
        try {
            s3.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
        } catch (SdkException e) {
            throw new IllegalStateException("Can't access S3 bucket '" + bucket + "' for post media: " + e.getMessage(), e);
        }
        log.info("Storing post media in s3://{}/{}", bucket, this.prefix);
    }

    public static String newKey(MediaType type) {
        return UUID.randomUUID().toString().replace("-", "") + "." + type.extension();
    }

    public static boolean isValidKey(String key) {
        return key != null && KEY.matcher(key).matches();
    }

    /**
     * A link the app can PUT exactly [size] bytes of [type] to. Content-Type and Content-Length are part of
     * the signature, so S3 refuses any other size or type.
     */
    public PresignedUpload presignUpload(String key, MediaType type, long size, Duration expiry) {
        PresignedPutObjectRequest presigned = presigner.presignPutObject(PutObjectPresignRequest.builder()
                .signatureDuration(expiry)
                .putObjectRequest(PutObjectRequest.builder()
                        .bucket(bucket)
                        .key(prefix + key)
                        .contentType(type.contentType())
                        .contentLength(size)
                        .cacheControl(CACHE_CONTROL)
                        .build())
                .build());
        // The client must send every signed header except Host, which its HTTP library sets itself
        Map<String, String> headers = new HashMap<>();
        presigned.signedHeaders().forEach((name, values) -> {
            if (!name.equalsIgnoreCase("host")) {
                headers.put(name, String.join(",", values));
            }
        });
        return new PresignedUpload(presigned.url().toString(), headers, presigned.expiration());
    }

    /** A time-limited link to read the file. */
    public String url(String key) {
        if (!isValidKey(key)) {
            return null;
        }
        return presigner.presignGetObject(GetObjectPresignRequest.builder()
                        .signatureDuration(downloadUrlExpiry)
                        .getObjectRequest(GetObjectRequest.builder().bucket(bucket).key(prefix + key).build())
                        .build())
                .url()
                .toString();
    }

    /** The uploaded file's size, or empty if nothing has been uploaded under this key. */
    public Optional<Long> size(String key) {
        try {
            return Optional.of(s3.headObject(HeadObjectRequest.builder().bucket(bucket).key(prefix + key).build()).contentLength());
        } catch (NoSuchKeyException e) {
            return Optional.empty();
        } catch (S3Exception e) {
            if (e.statusCode() == 404) {
                return Optional.empty();
            }
            throw e;
        }
    }

    /** The file's first [count] bytes, to check what it really is. */
    public byte[] readStart(String key, int count) {
        return s3.getObjectAsBytes(GetObjectRequest.builder()
                        .bucket(bucket)
                        .key(prefix + key)
                        .range("bytes=0-" + (count - 1))
                        .build())
                .asByteArray();
    }

    /** Removes the file; a missing file is not an error. */
    public void delete(String key) {
        if (!isValidKey(key)) {
            return;
        }
        try {
            s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(prefix + key).build());
        } catch (SdkException e) {
            log.warn("Could not delete s3://{}/{}{}: {}", bucket, prefix, key, e.getMessage());
        }
    }

    public void deleteAll(List<String> keys) {
        keys.forEach(this::delete);
    }
}
