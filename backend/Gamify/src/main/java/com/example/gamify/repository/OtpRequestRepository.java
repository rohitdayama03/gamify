package com.example.gamify.repository;

import com.example.gamify.entity.OtpRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.Optional;

public interface OtpRequestRepository extends JpaRepository<OtpRequest, Long> {

    // Holds a per-number lock until the transaction ends, so simultaneous requests can't all slip under the limits
    @Query(value = "select 1 from (select pg_advisory_xact_lock(hashtext(:phoneNumber))) locked", nativeQuery = true)
    int lockPhoneNumber(@Param("phoneNumber") String phoneNumber);

    long countByPhoneNumberAndCreatedAtGreaterThanEqual(String phoneNumber, OffsetDateTime since);

    Optional<OtpRequest> findFirstByPhoneNumberOrderByCreatedAtDesc(String phoneNumber);

    @Modifying
    @Query("delete from OtpRequest r where r.createdAt < :before")
    int deleteCreatedBefore(@Param("before") OffsetDateTime before);
}
