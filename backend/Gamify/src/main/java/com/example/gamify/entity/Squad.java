package com.example.gamify.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

/**
 * A group chat. {@code nameKey} is the lower-cased name, so "Night Owls" and "night owls" can't both exist.
 * The owner can remove members; when the owner leaves, the longest-standing member takes over.
 */
@Entity
@Table(name = "squads",
        uniqueConstraints = @UniqueConstraint(name = "uk_squad_name_key", columnNames = "name_key"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Squad {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name", nullable = false, length = 30)
    private String name;

    @Column(name = "name_key", nullable = false, length = 30)
    private String nameKey;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", referencedColumnName = "player_id", nullable = false)
    private Player owner;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }
}
