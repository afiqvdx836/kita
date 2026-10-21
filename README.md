# Kita

A couples app MVP (Flutter + Supabase), inspired by the Krivo teardown in `../krivo-teardown.md`.
"Kita" is a placeholder name, so rename it freely.

**In this MVP**
- Email + password sign up / sign in
- Pairing: one partner creates a 6-character invite code (valid 7 days), the other enters it
- Home: days-together counter plus the next milestone (every 100 days and each anniversary)
- Shared notes (pin, edit, delete) and shared tasks (add, tick, swipe to delete), both synced live between the two phones
- Unpair (leave the couple; the shared data stays with your partner)

## Layout

```
supabase/migrations/…_init.sql   tables, RLS, pairing RPCs, realtime
lib/
  main.dart                      Supabase init from --dart-define
  app.dart                       AuthGate → CoupleGate → Pairing | Home
  core/days.dart                 day counting + milestones (unit tested)
  core/stream_view.dart          subscribe-once StreamBuilder
  data/models.dart, repo.dart    all Supabase calls live in repo.dart
  features/{auth,pairing,home,notes,tasks}/
test/days_test.dart
```

## Security model

- Every shared row has `couple_id`. RLS allows access only when `couple_id = my_couple_id()`.
- Clients **cannot** set `profiles.couple_id` or touch `invites`. Pairing only happens through
  `create_invite()`, `join_couple(code)` and `leave_couple()` (security definer functions).
- A couple is capped at 2 members, a code is single-use, and `done_by` is stamped server-side.

## Setup

1. **Install Flutter** (you need ~3 GB free; your disk had 820 MB when this was written):
   `brew install --cask flutter`
2. **Generate the platform folders** (android/ios), which this hand-written scaffold doesn't include:
   ```bash
   cd kita && flutter create --org com.afiq --project-name kita --platforms android,ios .
   ```
3. **Create a Supabase project** → SQL Editor → paste and run
   `supabase/migrations/20261021000000_init.sql`.
   (Or use the CLI: `supabase link` then `supabase db push`.)
4. For dev, turn off **Authentication → Providers → Email → Confirm email**, so sign-up
   logs you straight in. (With it on, the app tells users to confirm by email first.)
5. `cp env.example.json env.json` and fill in your project URL + publishable key (Project Settings → API Keys).
6. Run it:
   ```bash
   flutter pub get
   flutter test
   flutter run --dart-define-from-file=env.json
   ```
7. To test pairing, run two simulators/devices (or one device + Chrome with `-d chrome`) and
   sign up two accounts.

## What was verified

- The SQL migration was applied to a throwaway Postgres 14 with stubbed Supabase `auth`
  and roles. Pairing and RLS behave as designed: code reuse, own-code rejected, joining
  brings solo notes/tasks along, a stranger sees nothing, a 3rd member is blocked, `done_by`
  can't be faked, and unpairing works.
- **The Dart code has not been compiled or run yet** (no Flutter SDK on this machine).
  Expect to fix a few small things on the first `flutter analyze`.

## Next steps (from the teardown)

Daily question (+ 8 PM reminder via FCM), Do-Together cards and This-or-That votes
(with your own BM-first content), calendar + date radar, RevenueCat paywall with free limits
(e.g. 5 notes / 20 tasks), home-screen widget for the day counter.
