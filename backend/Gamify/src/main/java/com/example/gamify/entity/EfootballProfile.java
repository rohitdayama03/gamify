package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "efootball_profiles", indexes = {
        @Index(name = "idx_efootball_tier", columnList = "high_tier")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EfootballProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "player_id", referencedColumnName = "player_id", nullable = false, unique = true)
    private Player player;

    @Column(name = "efootball_id", nullable = false, length = 50)
    private String efootballId;

    @Column(name = "high_tier", length = 50)
    private String highTier; // e.g., Division 1, Division 2

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}