package com.example.gamify.media;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;

/**
 * Connects to the media bucket. AWS credentials come from the SDK's default chain: the EC2 instance's IAM
 * role in production, or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / ~/.aws when running locally.
 */
@Configuration
@EnableConfigurationProperties(MediaProperties.class)
public class MediaStorageConfig {

    @Bean(destroyMethod = "")
    public MediaStorage mediaStorage(MediaProperties properties) {
        MediaProperties.S3 s3 = properties.s3();
        if (s3 == null || s3.bucket() == null || s3.bucket().isBlank()) {
            throw new IllegalStateException("Set MEDIA_S3_BUCKET to the S3 bucket for post photos and videos");
        }

        S3ClientBuilder client = S3Client.builder();
        S3Presigner.Builder presigner = S3Presigner.builder();
        if (s3.region() != null && !s3.region().isBlank()) {
            client.region(Region.of(s3.region()));
            presigner.region(Region.of(s3.region()));
        }
        if (s3.endpoint() != null && !s3.endpoint().isBlank()) {
            // S3-compatible servers usually want bucket-in-path URLs rather than bucket subdomains
            S3Configuration pathStyle = S3Configuration.builder().pathStyleAccessEnabled(true).build();
            client.endpointOverride(URI.create(s3.endpoint())).serviceConfiguration(pathStyle);
            presigner.endpointOverride(URI.create(s3.endpoint())).serviceConfiguration(pathStyle);
        }
        return new MediaStorage(client.build(), presigner.build(), s3.bucket(), s3.prefix(), s3.urlExpiry());
    }
}
