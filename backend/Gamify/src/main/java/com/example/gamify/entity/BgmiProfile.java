package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "bgmi_profiles", indexes = {
        @Index(name = "idx_bgmi_role", columnList = "player_role") // Updated column name here
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BgmiProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "player_id", referencedColumnName = "player_id", nullable = false, unique = true)
    private Player player;

    @Column(name = "bgmi_id", nullable = false, length = 50)
    private String bgmiId;

    // Renamed DB column name from current_role -> player_role
    @Column(name = "player_role", length = 50)
    private String currentRole;

    @Column(name = "experience", length = 50)
    private String experience;

    @Column(name = "available_time", length = 100)
    private String availableTime;

    @Column(name = "achievements", columnDefinition = "TEXT")
    private String achievements;

    @Column(name = "looking_for", length = 100)
    private String lookingFor;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}