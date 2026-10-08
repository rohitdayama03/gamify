package com.example.gamify.repository;

import com.example.gamify.entity.BgmiProfile;
import com.example.gamify.entity.EfootballProfile;
import com.example.gamify.entity.Player;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;

public class PlayerSpecification {

    public static Specification<Player> filterPlayers(
            String username,
            String country,
            String language,
            String bgmiRole,
            String efootballTier) {

        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (StringUtils.hasText(username)) {
                predicates.add(cb.like(cb.lower(root.get("username")), "%" + username.toLowerCase() + "%"));
            }

            if (StringUtils.hasText(country)) {
                predicates.add(cb.equal(cb.lower(root.get("country")), country.toLowerCase()));
            }

            if (StringUtils.hasText(language)) {
                predicates.add(cb.equal(cb.lower(root.get("language")), language.toLowerCase()));
            }

            if (StringUtils.hasText(bgmiRole)) {
                Join<Player, BgmiProfile> bgmiJoin = root.join("bgmiProfile", JoinType.INNER);
                predicates.add(cb.equal(cb.lower(bgmiJoin.get("currentRole")), bgmiRole.toLowerCase()));
            }

            if (StringUtils.hasText(efootballTier)) {
                Join<Player, EfootballProfile> efootballJoin = root.join("efootballProfile", JoinType.INNER);
                predicates.add(cb.equal(cb.lower(efootballJoin.get("highTier")), efootballTier.toLowerCase()));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}