package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/** One code sent to a phone number; also the record the daily send limit is counted from. */
@Entity
@Table(name = "otp_codes", indexes = {
        @Index(name = "idx_otp_phone_created", columnList = "phone_number, created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OtpCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "phone_number", nullable = false, length = 20)
    private String phoneNumber;

    @Enumerated(EnumType.STRING)
    @Column(name = "purpose", nullable = false, length = 20)
    private OtpPurpose purpose;

    // BCrypt hash, so a database leak doesn't expose live codes
    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;

    // Wrong guesses against this code; it stops working at the configured maximum
    @Column(name = "attempts", nullable = false)
    private int attempts;

    @Column(name = "used", nullable = false)
    private boolean used;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
