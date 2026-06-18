# Ledgerly — Cloud backend (Supabase + PowerSync)

Phase 0 provisions the cloud backend that the app syncs to. This directory holds
the **versioned, reviewable** definition of that backend; nothing here creates
live resources until you apply it.

> Decision (Phase 0): committed as **files only** — provision when ready. See
> `docs/09-security-privacy.md` for the security/compliance posture and
> `docs/13-technical-implementation-plan.md` §5 for the design.

## 1. Create the Supabase project

Prefer an **EU region** for data residency (docs/09 §5).

```bash
npm i -g supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push          # applies migrations/ to the project
```

`migrations/20260618000000_init_transactions.sql` creates the `transactions`
table, indexes, and **Row-Level Security** policies keyed to `auth.uid()`.

Enable **Email/Password** auth in the Supabase dashboard (Authentication →
Providers). OAuth/magic-link/MFA come in later phases.

## 2. Stand up PowerSync

1. Create a PowerSync instance and connect it to the Supabase Postgres
   (connection string + a logical replication user, per PowerSync docs).
2. Configure it to validate Supabase JWTs (use the project's JWKS/JWT secret).
3. Upload the sync rules from `sync_rules.yaml` (per-user `user_data` bucket).
4. Note the **PowerSync instance URL** for the app's `POWERSYNC_URL`.

## 3. Wire the app

Pass the three values at build/run time (no secrets in source — docs/09 §8;
only the **anon/publishable** key ships in the client, gated by RLS):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=POWERSYNC_URL=https://<instance>.powersync.journeyapps.com
```

## 4. Verify RLS (required before exposing any table to sync)

RLS misconfiguration is the highest-impact cloud risk (docs/10 R-19). Add
positive + cross-tenant-negative policy tests (e.g. `supabase test db` / pgTAP)
before Phase 1 adds more tables:

- a user can read/write **their own** rows;
- a user **cannot** read or write **another** user's rows.
