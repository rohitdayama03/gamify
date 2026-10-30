package com.example.gamify.config;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Accounts now sign in with a WhatsApp code, so new players have no password or security question.
 * Hibernate's schema update never relaxes NOT NULL on columns it no longer maps, so this does it once at
 * startup. The old values are kept; the columns can be dropped by hand once they're no longer wanted.
 */
@Component
@RequiredArgsConstructor
public class LegacyAuthColumns implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        jdbcTemplate.execute("""
                DO $$
                DECLARE col text;
                BEGIN
                    FOREACH col IN ARRAY ARRAY['password', 'secret_question', 'secret_answer'] LOOP
                        IF EXISTS (SELECT 1 FROM information_schema.columns
                                   WHERE table_name = 'players' AND column_name = col AND is_nullable = 'NO') THEN
                            EXECUTE format('ALTER TABLE players ALTER COLUMN %I DROP NOT NULL', col);
                        END IF;
                    END LOOP;
                END $$
                """);
    }
}
