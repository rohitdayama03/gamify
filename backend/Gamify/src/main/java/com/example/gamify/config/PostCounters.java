package com.example.gamify.config;

import com.example.gamify.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Posts keep like and comment counts so the feed can rank them. This recounts at startup: it fills them in
 * for posts made before the counts existed, and corrects any that drifted.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PostCounters implements ApplicationRunner {

    private final PostRepository postRepository;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        int fixed = postRepository.recountAll();
        if (fixed > 0) {
            log.info("Recounted likes and comments on {} posts", fixed);
        }
    }
}
