package com.example.gamify.entity;

import com.example.gamify.media.UploadKind;
import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * An upload link handed to a player that hasn't been used in a post yet. Committing the post consumes it;
 * if that doesn't happen by {@code expiresAt}, the cleanup job deletes the file and this row.
 */
@Entity
@Table(name = "pending_uploads",
        uniqueConstraints = @UniqueConstraint(name = "uk_pending_upload_key", columnNames = "media_key"),
        indexes = {
                @Index(name = "idx_pending_upload_owner", columnList = "owner_id"),
                @Index(name = "idx_pending_upload_expires", columnList = "expires_at")
        })
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PendingUpload {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "media_key", nullable = false, length = 64)
    private String mediaKey;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", referencedColumnName = "player_id", nullable = false)
    private Player owner;

    @Enumerated(EnumType.STRING)
    @Column(name = "kind", nullable = false, length = 20)
    private UploadKind kind;

    @Column(name = "content_type", nullable = false, length = 50)
    private String contentType;

    @Column(name = "size_bytes", nullable = false)
    private Long sizeBytes;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
