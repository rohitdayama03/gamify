package com.example.gamify.config;

import com.example.gamify.media.UploadKind;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.stream.Collectors;

/**
 * Hibernate guards each enum column with a CHECK listing the values the enum had when the table was created,
 * and its schema update never widens it, so a value added later is refused by the database. This rewrites
 * the check from the enum at startup for columns whose enum has grown.
 */
@Component
@RequiredArgsConstructor
public class EnumCheckConstraints implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        // AVATAR came after the table
        allow("pending_uploads", "kind", UploadKind.class);
    }

    private void allow(String table, String column, Class<? extends Enum<?>> type) {
        String constraint = table + "_" + column + "_check";
        // Enum constant names are plain identifiers, so quoting them is enough
        String values = Arrays.stream(type.getEnumConstants())
                .map(value -> "'" + value.name() + "'")
                .collect(Collectors.joining(", "));
        jdbcTemplate.execute("ALTER TABLE " + table + " DROP CONSTRAINT IF EXISTS " + constraint);
        jdbcTemplate.execute("ALTER TABLE " + table + " ADD CONSTRAINT " + constraint
                + " CHECK (" + column + " IN (" + values + "))");
    }
}
