# Security & Privacy

**Version:** 0.1 · **Date:** 2026-06-09

Financial data is sensitive. The product promise is **local-only, encrypted, no telemetry**. This document defines how.

---

## 1. Threat model

**In scope (defend against):**
- Theft/loss of the device or a copy of the database/backup file → data must be unreadable without the password (encryption at rest).
- Casual local access by another person on the machine → app lock.
- Accidental data exfiltration → no network egress of user data by default.

**Out of scope (explicitly):**
- A fully compromised OS / kernel-level malware / hardware keylogger while the user is actively using the app. We protect data **at rest**, not against an attacker who already owns the running machine.
- Forgotten master password → data is unrecoverable by design (no backdoor). This is communicated clearly to the user.

## 2. Encryption at rest (FR-SEC-01, FR-DAT-01, NFR-12)

- The SQLite database is encrypted with **SQLCipher** (AES-256-CBC, HMAC-SHA-512 page authentication) via `SQLitePCLRaw.bundle_e_sqlcipher`.
- The whole DB — transactions, line items, **OCR text**, and **attached documents** (if stored as BLOBs) — is therefore encrypted.
- Attachments stored as files (if ADR-004 chooses files) are encrypted individually with AES-256-GCM using a key derived from the master key.

## 3. Key management (FR-SEC-02)

- Master **password** → **KDF** (Argon2id preferred, or PBKDF2-HMAC-SHA256 with high iteration count if Argon2 lib is undesirable) with a per-install random salt → **master key**.
- The master key opens SQLCipher (`PRAGMA key`). It is **never written to disk in plaintext**.
- Key held in memory only while unlocked; cleared/zeroed on lock/exit where the runtime allows (`SecureString`/pinned buffers, best-effort given .NET GC).
- Salt + KDF parameters stored in a small local config (non-secret).
- **Password change** re-derives the key and re-keys the DB (`PRAGMA rekey`).

## 4. Authentication & session (FR-SEC-02/03/05)

- App requires master password on launch and after auto-lock.
- **Windows Hello** (v0.3): the master key is wrapped by a Windows Hello–protected credential (Windows `KeyCredentialManager` / DPAPI tied to the user) for convenient unlock, with password always available as fallback.
- **Auto-lock** (v1.0): configurable idle timeout locks the app and drops the in-memory key (FR-SEC-05).

## 5. Privacy / no telemetry (NFR-04)

- **No analytics, no telemetry, no crash phone-home** by default. Logs are local files only (Serilog).
- The app functions fully offline; this is testable by running firewalled.
- The **only** outbound network calls are optional, explicit, user-initiated: exchange-rate fetch (FR-CUR-05) and update checks (v1.0). Both are off by default / clearly opt-in, and never transmit financial data.
- OCR is on-device (no document or text ever uploaded) — the central privacy reason for choosing local OCR.

## 6. Backups & recovery (FR-DAT-02/03, NFR-05/13)

- **Manual backup**: export the encrypted DB (and attachments) as a single archive to a user-chosen location (local drive, or a synced folder like OneDrive for an off-box copy). The backup stays **encrypted** — moving it to cloud storage does not expose plaintext.
- **Restore**: validates integrity (checksum) and that the password decrypts it before overwriting; current data is snapshotted first.
- **Automatic pre-migration snapshot**: before any schema migration, copy the DB to `backups/auto/` so an upgrade can be rolled back (NFR-05).
- WAL journaling + transactional writes prevent corruption on crash/power loss.
- Clear messaging: **backups inherit master-password protection; lose the password = lose the data.**

## 7. Data integrity

- Foreign keys enforced; soft-delete with undo; purge after retention window.
- SHA-256 on attachments for dedupe & tamper detection.
- Money stored as `decimal` with explicit rounding to avoid silent drift (NFR-12, [04 §3.4](04-data-model.md)).

## 8. Secure development practices

- Nullable reference types + analyzers on; input validation (FluentValidation) on all user/OCR-sourced data.
- No secrets in source; no hardcoded keys.
- Dependencies pinned and periodically audited (`dotnet list package --vulnerable`) — done locally, not a runtime dependency.
- Principle of least privilege: app needs no admin rights (NFR-10), no network capability required at runtime.

## 9. Compliance posture

- Single-user, local, personal-use app: no third-party data processing, so GDPR processor obligations don't arise. The user is the sole controller of their own data on their own device. No PII leaves the device.

## 10. User-facing security summary (for onboarding copy)

> Your data lives only on this PC, encrypted with your master password. We never send your finances anywhere. If you forget your password, your data cannot be recovered — keep a safe backup and remember your password.
