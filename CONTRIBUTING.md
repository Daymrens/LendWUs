# Contributing to LendWUs

LendWUs is a small family-circle project (Flutter + Firebase mobile app, React/TS marketing site). This doc keeps things consistent even with a tiny contributor base.

## Branching

- `master` is the deployable branch — keep it working.
- For non-trivial changes, branch off: `feature/<short-description>`, `fix/<short-description>`, `chore/<short-description>`.
- Small fixes can be committed directly to `master` if you're the sole active contributor, but prefer a branch + PR for anything touching `firestore.rules`, loan/repayment logic, or returns calculations — these affect real money tracking.

## Commit Messages

Use a short prefix + imperative description:

```
fix: correct interest calculation rounding in repayment summary
feat: add head change request approval screen
chore: bump pubspec dependencies
docs: update firestore schema reference
refactor: extract loan eligibility check into repository
```

Keep the first line under ~72 chars. Add a body if the "why" isn't obvious from the diff.

## Before Submitting Changes

Run these locally:

```bash
# Static analysis (must be clean — analysis_options.yaml)
flutter analyze

# Unit/widget tests
flutter test
```

For website changes:

```bash
cd website
npm run build   # must succeed without TS errors
```

If you touched `firestore.rules` or `firestore.indexes.json`, also:

- Re-read the affected `match` blocks and confirm the change doesn't widen access unintentionally (see `docs/firestore-schema.md` for the access model).
- If you added a new compound query, add the matching entry to `firestore.indexes.json` — otherwise it'll fail in production with a missing-index error even if it works against cached/local data.

## Testing Against Firebase

This project has **no Cloud Functions** (Spark plan) — all enforcement is client + `firestore.rules`. When testing:

- Prefer the Firebase Local Emulator Suite for rules changes (`firebase emulators:start`) so you don't risk writing bad data to the live `lmsystemm` project.
- If testing against the live project, use a non-admin test account where possible — don't use `act.drapor@gmail.com` / `daymrens@gmail.com` for routine testing since these have admin access.
- Never commit real member data, receipts, or production Firestore exports.

## Code Style

- **Dart**: follow `analysis_options.yaml`. Run `dart format .` before committing.
- **Riverpod**: new data-backed providers go in `lib/providers`; Firestore access goes through `lib/data/repositories`, never directly in widgets.
- **Models**: add `fromJson`/`toJson` (or Firestore equivalents) with null-safe defaults — see existing models in `lib/data/models` for the pattern.
- **Money**: all monetary values are stored and computed as **integer centavos** (see `sinking_fund_logic.md` §10). Never introduce floating-point currency math.
- **TypeScript (website)**: avoid `any`; define interfaces for section/content data in `App.tsx`.

## Domain Logic Changes

If your change affects fund balance, loan eligibility, interest, repayments, or returns calculations:

1. Read `sinking_fund_logic.md` first — it's the source of truth for formulas and validation rules.
2. Update `sinking_fund_logic.md` if the formula or rule changes.
3. Add/update a test covering the new behavior (especially edge cases listed in §11 of that doc).

## Security-Sensitive Changes

Treat these as higher-risk and double-check before merging:

- Any edit to `firestore.rules`
- Any change to admin-detection logic (`isAdmin()`, `adminEmails`, `users/{uid}.role`)
- Any change to who can `create`/`update` `contributions`, `loans`, `repayments`, or `returns`

When in doubt, re-read `docs/firestore-schema.md` for the current access model before changing it.

## Reporting Issues

Since this app tracks real family finances, please report bugs with:

- What screen/action you were on
- Expected vs actual numbers (if it's a calculation bug)
- Whether you're an admin or member account

Open an issue on GitHub or message the maintainer directly for anything urgent involving incorrect balances.
