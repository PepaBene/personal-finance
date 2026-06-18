# Security & Privacy

**Version:** 0.2 (draft) · **Date:** 2026-06-18 · **Status:** Pre-implementation — Flutter re-platform

Financial data is sensitive. Ledgerly is now **offline-first AND cloud-backed**: each device holds a full encrypted local database and changes sync, encrypted, to a cloud backend so every device converges (see [01](01-product-requirements.md), [03](03-architecture.md)). The product promise is **encrypted everywhere — on device, in transit, and in the cloud — with opt-in-only telemetry and strong tenant isolation**. This is a deliberate change from the old local-only, no-cloud model, and it brings new privacy and compliance obligations that this document states honestly (see §9).

---

## 1. Threat model

The threat surface now spans **device + network + cloud**, not just the local machine.

**In scope (defend against):**
- **Device:** theft/loss of a device or a copy of the local database/backup → data unreadable without the user's credentials (encryption at rest).
- **Device:** casual local access by another person → app lock + auto-lock + biometric unlock.
- **Network:** eavesdropping or tampering on the wire → TLS for all transport; client-side encryption for attachments and sensitive payloads on top of TLS.
- **Cloud:** a compromised or curious backend operator, or a misconfiguration, reading one tenant's data → Row-Level Security tenant isolation, plus client-side AES-256-GCM so the most sensitive blobs are opaque to the server.
- **Cloud:** cross-tenant leakage via a bad query/policy → RLS keyed to `auth.uid()`, tested.
- **Account:** credential stuffing / unauthorized sign-in → Supabase Auth with optional MFA, refresh-token rotation.

**Out of scope (explicitly):**
- A fully compromised OS / kernel-level malware / hardware keylogger while the user is actively using an unlocked app. We protect data **at rest and in transit**, not against an attacker who already owns the running, unlocked device.
- Loss of **both** the account password **and** the recovery phrase → data protected by client-side encryption is unrecoverable by design (no backdoor; see §3). This is communicated clearly to the user.
- Targeted compromise of the cloud provider's infrastructure beyond what RLS + client-side encryption + the DPA mitigate.

## 2. Encryption (FR-SEC-01, FR-DAT-01, NFR-12)

Defence in depth across all three tiers:

- **Device at rest:**
  - Native (iOS/Android/Windows/macOS/Linux): the SQLite database is encrypted with **SQLCipher** (AES-256) via `sqlite3` + `sqlcipher_flutter_libs`, opened by Drift with a key derived from the user's passphrase (§3). The whole local DB — transactions, line items, **OCR text**, metadata — is therefore encrypted.
  - **Web:** Drift runs as **WASM with OPFS** (Origin Private File System) storage; the database key and an app-level encryption layer use a **non-extractable WebCrypto** key, so secrets are never exposed to JS as raw bytes. (Where SQLCipher is unavailable on web, app-level field encryption protects sensitive columns.)
- **In transit:** **TLS** for all client↔Supabase traffic (Postgres, Auth, Storage, PowerSync).
- **Cloud at rest:** **Postgres** and **Supabase Storage** are encrypted at rest by the provider.
- **Tenant isolation:** **Supabase Row-Level Security**, with every policy keyed to `auth.uid()`, ensures a user can only read/write their own rows; PowerSync sync rules stream only the owner's rows to a device.
- **Client-side encryption (end-to-end for the most sensitive data):** **attachments** (receipt/invoice images & PDFs) and designated **sensitive payloads** are encrypted on-device with **AES-256-GCM** before upload, so they are stored as opaque blobs the server cannot read. Encrypted attachments go to **Supabase Storage**; metadata + OCR text stay in the DB. See [08 Phase 2](08-implementation-roadmap.md).

## 3. Key management (FR-SEC-02)

- The user's **passphrase** → **Argon2id** KDF (per-account/per-install salt, tuned memory/iterations/parallelism — see open questions in [10](10-risks-and-decisions.md)) → a **master key**.
- The master key (a) opens the local encrypted DB and (b) is the root for the **content encryption key (CEK)** used for client-side AES-256-GCM of attachments/sensitive payloads.
- **Multi-device:** the CEK is **wrapped** (encrypted) under a key derived from the passphrase and stored alongside the account, so a new device that authenticates and supplies the passphrase can unwrap the same CEK and decrypt synced data. The plaintext CEK is **never** sent to or stored by the server.
- **Recovery phrase:** at onboarding the user is given a high-entropy **recovery phrase** that also wraps the CEK. This means a **forgotten password is recoverable** via the recovery phrase (re-derive, unwrap, set a new password). **Losing both password and recovery phrase = unrecoverable**, by design.
- Keys are held in memory only while unlocked and cleared on lock/exit where the runtime allows (best-effort given Dart GC). KDF parameters + salt are stored as non-secret config.
- **Password change** re-derives the wrapping key and re-wraps the CEK (and re-keys the local DB) without re-encrypting all content.
- OS-backed secret storage via **flutter_secure_storage** (Keychain / Keystore / DPAPI / libsecret) holds session tokens and, where appropriate, a biometric-wrapped unlock secret; web uses a non-extractable WebCrypto key.

## 4. Authentication & session (FR-SEC-02/03/05)

- **Supabase Auth**: email + password, OAuth (Apple/Google), and magic-link sign-in.
- **JWT + refresh tokens** stored in `flutter_secure_storage`; refresh-token rotation; sign-out revokes the session.
- **Optional MFA** for accounts that want a second factor on sign-in.
- **Biometric local unlock** via `local_auth` (Face ID / Touch ID / Android biometrics / Windows Hello); the local key is wrapped by a biometric-protected credential, with passphrase always available as fallback. Web falls back to passphrase.
- **Auto-lock** (FR-SEC-05): configurable idle timeout locks the app and drops the in-memory keys.

## 5. Privacy & telemetry (NFR-04)

- **Opt-in only**: no analytics, no telemetry, and no crash phone-home unless the user explicitly enables it. When enabled, crash reporting uses **Sentry**; financial data is never included in telemetry. Logs are local files (`logger`/`talker`) by default.
- **OCR is on-device by default** (no document or text uploaded). An **opt-in cloud OCR fallback** (Supabase Edge Function) exists for hard documents only and is clearly flagged.
- **Data residency:** user data lives in the configured **Supabase region** (preferring an **EU** region); the chosen region is documented and surfaced to the user. See open questions in [10](10-risks-and-decisions.md).
- A **privacy policy** describes what is stored, where, and for how long, plus how to export or delete data (§9).

## 6. Backups & recovery (FR-DAT-02/03, NFR-05/13)

- **Cloud is the always-on backup:** because every change syncs to the cloud, a lost or wiped device is recovered by signing in on a new device, syncing down, and supplying the passphrase/recovery phrase to unwrap encrypted content.
- **Encrypted local export/import** is still offered: export the local data (and attachments) as a single **encrypted** archive to a user-chosen location for an off-cloud copy; restore validates integrity (checksum) and decryptability before overwriting, snapshotting current data first.
- **Automatic pre-migration snapshot:** before any local schema migration, copy the local DB to `backups/auto/` so an upgrade can be rolled back (NFR-05).
- WAL journaling + transactional writes prevent local corruption on crash/power loss.
- Clear messaging: **encrypted content is protected by your password and recovery phrase; lose both and that data cannot be recovered — not even by us.**

## 7. Data integrity

- Foreign keys enforced; **soft-delete tombstones** (`deleted`) with undo, purged after a retention window — tombstones also drive correct multi-device deletion via sync.
- Per-row `updatedAt` (UTC) + version/clock drive **last-write-wins** conflict resolution; children (LineItems) keyed to parent (FR-SYNC-03, [04](04-data-model.md)).
- SHA-256 on attachments for dedupe & tamper detection.
- Money stored as `decimal` (TEXT) with explicit rounding to avoid silent drift (NFR-12, [04 §3.4](04-data-model.md)).

## 8. Secure development practices

- Sound null-safety + analyzer/lints as errors; input validation (`form_builder_validators` + custom validators) on all user/OCR-sourced data.
- No secrets in source; no hardcoded keys; Supabase service-role keys never ship in the client (only the publishable/anon key, gated by RLS).
- **RLS policies are tested** (positive and cross-tenant-negative cases) and reviewed before any table is exposed to sync — a misconfigured policy is the highest-impact cloud risk (see [10](10-risks-and-decisions.md) R-19).
- Dependencies pinned and periodically audited; Supabase advisors/lints reviewed each phase.
- Principle of least privilege: the app needs no elevated OS rights; the backend grants each tenant access only to its own rows.

## 9. Compliance posture (changed: GDPR now applies)

Unlike the old local-only product — where no third party processed data and GDPR processor obligations did not arise — **we now host user data in the cloud, so GDPR applies.**

- **Controller / processor split:** the operator of Ledgerly's backend is the **data controller** for users' account data; **Supabase acts as a data processor** under a **Data Processing Agreement (DPA)**. Any other sub-processor (e.g. opt-in crash reporting) is documented.
- **Lawful basis & transparency:** processing is on the basis of providing the requested service (and consent for opt-in telemetry); the privacy policy discloses purposes, categories, retention, and sub-processors.
- **Data residency:** data stored in the chosen Supabase region (preferring EU); cross-border transfers, if any, covered by the appropriate safeguards.
- **Right to erasure:** **account deletion** removes the user's cloud data (DB rows + Storage objects) and tombstones propagate locally; documented and self-service.
- **Data portability:** **data export** provides the user's data in a portable, documented format (e.g. CSV/JSON, plus original attachments).
- **Data minimization & security:** client-side encryption, RLS, and opt-in-only telemetry keep the hosted footprint minimal and protected.
- **Honest framing:** these obligations are the direct cost of cloud sync. The old model had none because nothing left the device; the new model trades that for seamless multi-device sync and cloud backup, and we take on the corresponding responsibilities.

## 10. User-facing security summary (for onboarding copy)

> Your finances are encrypted on every device, encrypted in transit, and encrypted in the cloud — and only you hold the keys to your most sensitive data, like receipts. Sign in on any device to pick up where you left off. Your data is stored in your chosen region. If you forget your password, you can recover access with your recovery phrase — so **save your recovery phrase somewhere safe.** Lose both your password and recovery phrase, and your encrypted data can't be recovered, not even by us. We don't track you: analytics and crash reporting are off unless you turn them on. You can export or permanently delete all of your data at any time.
