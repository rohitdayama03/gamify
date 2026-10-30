package com.example.gamify.repository;

import com.example.gamify.entity.OtpCode;
import com.example.gamify.entity.OtpPurpose;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface OtpCodeRepository extends JpaRepository<OtpCode, Long> {

    long countByPhoneNumberAndCreatedAtGreaterThanEqual(String phoneNumber, OffsetDateTime since);

    Optional<OtpCode> findFirstByPhoneNumberAndPurposeAndUsedFalseOrderByCreatedAtDesc(String phoneNumber, OtpPurpose purpose);
}
