package com.example.gamify.repository;

import com.example.gamify.entity.OtpCode;
import com.example.gamify.entity.OtpPurpose;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface OtpCodeRepository extends JpaRepository<OtpCode, Long> {

    Optional<OtpCode> findFirstByPhoneNumberAndPurposeAndUsedFalseOrderByCreatedAtDesc(String phoneNumber, OtpPurpose purpose);

    @Modifying
    @Query("delete from OtpCode c where c.createdAt < :before")
    int deleteCreatedBefore(@Param("before") OffsetDateTime before);
}
