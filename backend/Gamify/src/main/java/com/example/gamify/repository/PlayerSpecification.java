package com.example.gamify.repository;

import com.example.gamify.entity.BgmiProfile;
import com.example.gamify.entity.EfootballProfile;
import com.example.gamify.entity.Game;
import com.example.gamify.entity.Player;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;

public class PlayerSpecification {

    public static Specification<Player> isNotPlayer(String username) {
        return (root, query, cb) -> cb.notEqual(root.get("username"), username);
    }

    public static Specification<Player> filterPlayers(
            String username,
            String country,
            String language,
            Game game,
            String gtaPlatform,
            String gtaActivity,
            String bgmiRole,
            String efootballTier) {

        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            // Filtering by game means the player has a profile for it, since that's where its details live
            if (game != null) {
                predicates.add(cb.isNotNull(root.join(profileField(game), JoinType.LEFT).get("id")));
            }

            if (StringUtils.hasText(gtaPlatform) || StringUtils.hasText(gtaActivity)) {
                Join<Player, ?> gtaJoin = root.join("gtaProfile", JoinType.INNER);
                if (StringUtils.hasText(gtaPlatform)) {
                    predicates.add(cb.equal(cb.lower(gtaJoin.get("platform")), gtaPlatform.toLowerCase()));
                }
                // activities holds a comma-separated list ("Heist,Racing"); match one whole entry
                if (StringUtils.hasText(gtaActivity)) {
                    Expression<String> paddedActivities = cb.concat(cb.concat(",", cb.lower(gtaJoin.get("activities"))), ",");
                    predicates.add(cb.like(paddedActivities, "%," + gtaActivity.trim().toLowerCase() + ",%"));
                }
            }

            if (StringUtils.hasText(username)) {
                predicates.add(cb.like(cb.lower(root.get("username")), "%" + username.toLowerCase() + "%"));
            }

            if (StringUtils.hasText(country)) {
                predicates.add(cb.equal(cb.lower(root.get("country")), country.toLowerCase()));
            }

            // language holds a comma-separated list ("English, Hindi"); match one whole entry
            if (StringUtils.hasText(language)) {
                Expression<String> paddedList = cb.concat(cb.concat(", ", cb.lower(root.get("language"))), ",");
                predicates.add(cb.like(paddedList, "%, " + language.trim().toLowerCase() + ",%"));
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

    /**
     * Free-text search: username prefix, or everyone who plays [game] when the text names one.
     * Username matches are listed first so typing a name finds that player straight away.
     */
    public static Specification<Player> matchesSearchText(String text, Game game) {
        String prefix = escapeLike(text.trim().toLowerCase()) + "%";

        return (root, query, cb) -> {
            Predicate usernameMatch = cb.like(cb.lower(root.get("username")), prefix, '\\');
            Predicate result = game == null ? usernameMatch : cb.or(usernameMatch, playsGame(root, cb, game));

            // Count queries can't be ordered; Spring Data also drops this ordering when a sort is requested
            if (query != null && !Long.class.equals(query.getResultType())) {
                query.orderBy(
                        cb.asc(cb.selectCase().when(usernameMatch, 0).otherwise(1)),
                        cb.desc(root.get("createdAt"))
                );
            }
            return result;
        };
    }

    // A player plays a game if they have a profile for it or picked it as one of their games
    private static Predicate playsGame(Root<Player> root, CriteriaBuilder cb, Game game) {
        Join<Player, ?> profile = root.join(profileField(game), JoinType.LEFT);
        // interestedGames is stored as "GTA,BGMI"; pad it so we match one whole entry
        Expression<String> paddedInterests = cb.concat(cb.concat(",", cb.coalesce(root.get("interestedGames"), "")), ",");
        return cb.or(cb.isNotNull(profile.get("id")), cb.like(paddedInterests, "%," + game.name() + ",%"));
    }

    private static String profileField(Game game) {
        return switch (game) {
            case GTA -> "gtaProfile";
            case BGMI -> "bgmiProfile";
            case EFOOTBALL -> "efootballProfile";
        };
    }

    // Treat % and _ typed by the user as literal characters
    private static String escapeLike(String value) {
        return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}