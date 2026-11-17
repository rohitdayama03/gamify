package com.example.gamify.config;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * A participant row in a started tournament outlives the player's account (the fixtures point at it), so
 * {@code player_id} may now be null. Hibernate's schema update never relaxes NOT NULL, so this does it once
 * at startup.
 */
@Component
@RequiredArgsConstructor
public class TournamentParticipantColumns implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        jdbcTemplate.execute("""
                DO $$
                BEGIN
                    IF EXISTS (SELECT 1 FROM information_schema.columns
                               WHERE table_name = 'tournament_participants' AND column_name = 'player_id'
                               AND is_nullable = 'NO') THEN
                        ALTER TABLE tournament_participants ALTER COLUMN player_id DROP NOT NULL;
                    END IF;
                END $$
                """);
    }
}
