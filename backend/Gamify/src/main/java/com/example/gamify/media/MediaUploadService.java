package com.example.gamify.media;

import com.example.gamify.dto.CreateUploadsRequest;
import com.example.gamify.dto.UploadSessionResponse;
import com.example.gamify.dto.UploadTicketResponse;
import com.example.gamify.entity.PendingUpload;
import com.example.gamify.entity.Player;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.repository.PendingUploadRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Direct uploads to S3, one post at a time per player. Starting a post hands out signed PUT links for its
 * files (an upload session); the app uploads to S3 itself, then commits the post, and {@link #claim} checks
 * each file before the post is saved. Committing or cancelling ends the session. A session that's abandoned
 * stops blocking new posts once its links expire, and {@link #deleteExpired} removes its files.
 * Profile pictures go the same way, one file at a time, without touching a post being uploaded.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MediaUploadService {

    // Enough to recognise every supported format
    private static final int SNIFF_BYTES = 12;

    private static final int CLEANUP_BATCH = 100;

    private final MediaStorage mediaStorage;
    private final MediaProperties properties;
    private final PendingUploadRepository pendingUploadRepository;
    private final EntityManager entityManager;

    /** The file a committed post now owns. */
    public record ClaimedUpload(String key, long size) {}

    @Transactional
    public UploadSessionResponse startSession(Player owner, CreateUploadsRequest request) {
        List<CreateUploadsRequest.File> files = request.files();
        if (files.stream().anyMatch(f -> f.kind() == UploadKind.AVATAR)) {
            throw new BadRequestException("Profile pictures are uploaded from your profile, not as a post");
        }
        long main = files.stream().filter(f -> f.kind() != UploadKind.THUMBNAIL).count();
        boolean video = files.stream().anyMatch(f -> f.kind() == UploadKind.VIDEO);
        boolean thumbnail = files.stream().anyMatch(f -> f.kind() == UploadKind.THUMBNAIL);
        if (main != 1 || (thumbnail && !video)) {
            throw new BadRequestException("A post has one photo or video, plus a thumbnail for videos");
        }
        // Check every file before handing out any link
        List<MediaType> types = new ArrayList<>();
        for (CreateUploadsRequest.File file : files) {
            types.add(checkFile(file));
        }

        lockPostingFor(owner);
        requireNoPostInProgress(owner);
        // Anything left from an earlier, abandoned post can go now
        discard(pendingUploadRepository.findPostUploads(owner));

        List<Issued> issued = new ArrayList<>();
        for (int i = 0; i < files.size(); i++) {
            issued.add(issue(owner, files.get(i), types.get(i)));
        }
        return toSession(issued);
    }

    /**
     * A signed link for a new profile picture, replacing any earlier one that was never saved. Claim it with
     * {@link #claim} as {@link UploadKind#AVATAR}. Doesn't affect a post being uploaded.
     */
    @Transactional
    public UploadSessionResponse startAvatarUpload(Player owner, String contentType, long size) {
        CreateUploadsRequest.File file = new CreateUploadsRequest.File(UploadKind.AVATAR, contentType, size);
        MediaType type = checkFile(file);
        lockPostingFor(owner);
        discard(pendingUploadRepository.findAllByOwnerAndKind(owner, UploadKind.AVATAR));
        return toSession(List.of(issue(owner, file, type)));
    }

    /** Gives up on the post being uploaded (e.g. an upload failed): its files are deleted and a new post may start. */
    @Transactional
    public void cancelSession(Player owner) {
        lockPostingFor(owner);
        discard(pendingUploadRepository.findPostUploads(owner));
    }

    /**
     * Call before committing a post, in its transaction. Waits for any other post this player is committing,
     * and refuses a post without files (text) while a photo or video post is still uploading.
     */
    @Transactional
    public void beginCommit(Player owner, boolean withFiles) {
        lockPostingFor(owner);
        if (!withFiles) {
            requireNoPostInProgress(owner);
        }
    }

    /**
     * Hands an uploaded file to the post being committed: it must be from this player's current upload, of
     * [kind], fully uploaded, the size they declared, and really that kind of file. A file that fails the
     * checks is deleted. Call after {@link #beginCommit}, so the session is only consumed if the post is saved.
     */
    @Transactional
    public ClaimedUpload claim(Player owner, String key, UploadKind kind) {
        Map<String, PendingUpload> session = pendingUploadRepository.findAllByOwner(owner).stream()
                .collect(Collectors.toMap(PendingUpload::getMediaKey, Function.identity()));
        PendingUpload pending = MediaStorage.isValidKey(key) ? session.get(key) : null;
        if (pending == null || pending.getKind() != kind || !pending.getExpiresAt().isAfter(OffsetDateTime.now())) {
            throw new BadRequestException("That upload has expired or doesn't exist. Please upload the file again.");
        }

        // Not there yet means the upload didn't finish; leave the session so the app can retry the commit
        long size = mediaStorage.size(key)
                .orElseThrow(() -> new BadRequestException("The upload hasn't finished. Please try again."));
        MediaType detected = MediaType.detect(mediaStorage.readStart(key, SNIFF_BYTES)).orElse(null);
        if (size != pending.getSizeBytes() || detected == null || !detected.contentType().equals(pending.getContentType())) {
            // S3 enforces the signed size and type, so a mismatch means the contents aren't what was declared
            mediaStorage.delete(key);
            throw new BadRequestException(kind.allowedDescription());
        }
        pendingUploadRepository.delete(pending);
        return new ClaimedUpload(key, size);
    }

    /** After a post's files are claimed: anything else in the session wasn't used, so the session ends. */
    @Transactional
    public void endSession(Player owner) {
        discard(pendingUploadRepository.findPostUploads(owner));
    }

    /** Deletes uploads that were never committed, a batch at a time. */
    @Scheduled(fixedDelayString = "${app.media.cleanup-interval}", initialDelayString = "${app.media.cleanup-interval}")
    @Transactional
    public void deleteExpired() {
        List<PendingUpload> expired = pendingUploadRepository.findExpired(OffsetDateTime.now(), PageRequest.of(0, CLEANUP_BATCH));
        if (expired.isEmpty()) {
            return;
        }
        discard(expired);
        log.info("Deleted {} uploads that were never posted", expired.size());
    }

    /** Deletes files a saved row no longer points at, once the transaction commits (straight away outside one). */
    public void deleteAfterCommit(List<String> keys) {
        List<String> present = keys.stream().filter(Objects::nonNull).toList();
        if (present.isEmpty()) {
            return;
        }
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            present.forEach(mediaStorage::delete);
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                present.forEach(mediaStorage::delete);
            }
        });
    }

    /** Removes a player's uncommitted uploads before their account is deleted. */
    @Transactional
    public void deleteAllFor(Player owner) {
        discard(pendingUploadRepository.findAllByOwner(owner));
    }

    private record Issued(UploadTicketResponse ticket, OffsetDateTime linkExpiresAt) {}

    // Signs an upload link for the file and remembers it until it's claimed or expires
    private Issued issue(Player owner, CreateUploadsRequest.File file, MediaType type) {
        String key = MediaStorage.newKey(type);
        MediaStorage.PresignedUpload upload = mediaStorage.presignUpload(key, type, file.size(), properties.uploadUrlExpiry());
        pendingUploadRepository.save(PendingUpload.builder()
                .mediaKey(key)
                .owner(owner)
                .kind(file.kind())
                .contentType(type.contentType())
                .sizeBytes(file.size())
                .expiresAt(OffsetDateTime.now().plus(properties.pendingUploadTtl()))
                .build());
        return new Issued(new UploadTicketResponse(file.kind(), key, upload.url(), "PUT", upload.headers()),
                upload.expiresAt().atOffset(ZoneOffset.UTC));
    }

    private static UploadSessionResponse toSession(List<Issued> issued) {
        return new UploadSessionResponse(
                issued.stream().map(Issued::ticket).toList(),
                issued.get(issued.size() - 1).linkExpiresAt());
    }

    private MediaType checkFile(CreateUploadsRequest.File file) {
        UploadKind kind = file.kind();
        MediaType type = MediaType.fromContentType(file.contentType())
                .filter(kind::allows)
                .orElseThrow(() -> new BadRequestException(kind.allowedDescription()));
        long max = kind.maxBytes(properties);
        if (file.size() > max) {
            throw new BadRequestException(describe(kind) + " can be up to " + Math.max(1, max / (1024 * 1024)) + " MB");
        }
        return type;
    }

    // One post at a time: links handed out within the link lifetime may still be uploading
    private void requireNoPostInProgress(Player owner) {
        OffsetDateTime since = OffsetDateTime.now().minus(properties.uploadUrlExpiry());
        if (pendingUploadRepository.existsStartedAfter(owner, since)) {
            throw new BadRequestException("You're already posting something. Wait for it to finish, then try again.");
        }
    }

    // Serialises a player's posting requests (e.g. a double tap, or two phones) on their player row
    private void lockPostingFor(Player owner) {
        entityManager.lock(owner, LockModeType.PESSIMISTIC_WRITE);
    }

    private void discard(List<PendingUpload> uploads) {
        if (uploads.isEmpty()) {
            return;
        }
        mediaStorage.deleteAll(uploads.stream().map(PendingUpload::getMediaKey).toList());
        pendingUploadRepository.deleteAll(uploads);
    }

    private static String describe(UploadKind kind) {
        return switch (kind) {
            case IMAGE -> "Images";
            case VIDEO -> "Videos";
            case THUMBNAIL -> "Thumbnails";
            case AVATAR -> "Profile pictures";
        };
    }
}
