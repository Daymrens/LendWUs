# AGENTS.md — LendWUs

A family-circle sinking fund (paluwagan) app: group savings, loans, and returns tracking.

- **Mobile**: Flutter + Dart
- **Web**: React 18 + TypeScript marketing site
- **Backend**: Firebase (Auth, Cloud Firestore, Hosting) — **Spark plan, no Cloud Functions**

## Setup

```bash
# Mobile deps
flutter pub get

# Website deps
cd website && npm install
```

Firebase Console setup (project `lmsystemm`):
- Enable **Email/Password** and **Google Sign-In** under Authentication providers.
- Google Sign-In debug SHA-1: `B5:BD:8F:C3:D7:F9:E7:57:83:2B:C8:EE:5D:DC:56:2F:FA:36:BF:FB`

Hardcoded admin emails (auto-linked on Google sign-in):
- `act.drapor@gmail.com`
- `daymrens@gmail.com`

## Run

```bash
# Mobile app
flutter run

# Website (dev server)
cd website && npm start

# Website (build + deploy)
cd website && npm run build
npx firebase deploy --only hosting
```

## Build

```bash
# Debug APK
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

## Lint / Analyze

```bash
# Dart static analysis (uses analysis_options.yaml)
flutter analyze

# Run tests
flutter test
```

For the website, use whatever lint/test scripts are defined in `website/package.json` (e.g. `npm run lint`, `npm test`) if present.

## Project Structure

```
lib/
├── core/
│   ├── theme/          # AppColors, dark theme
│   ├── utils/          # CurrencyFormatter
│   └── widgets/        # LendWUsLogo
├── data/
│   ├── models/         # Loan, Member, PaymentRequest, Repayment, etc.
│   └── repositories/   # Firestore CRUD per collection
├── providers/           # Riverpod providers
└── screens/             # UI screens organized by role/feature

website/
├── public/
└── src/
    ├── App.tsx          # Single-page landing (nav, hero, features, etc.)
    ├── App.css          # Fully responsive (mobile hamburger nav)
    └── firebase.ts       # Firebase config
```

## Tech Stack & Conventions

| Layer      | Technology                            |
| ---------- | -------------------------------------- |
| Mobile     | Flutter & Dart                         |
| Web        | React 18 + TypeScript                  |
| State Mgmt | Riverpod (providers + StreamProvider)  |
| Navigation | go_router                              |
| Auth       | Firebase Auth (email + Google)         |
| Database   | Cloud Firestore (NoSQL)                |
| Backend    | Firebase Spark plan — no Functions     |
| Hosting    | Firebase Hosting                       |
| Charts     | fl_chart                                |
| Icons      | lucide-react (website)                 |

### Conventions

- **Repository pattern**: all Firestore reads/writes go through `lib/data/repositories`, never directly from widgets or providers.
- **State**: Riverpod providers in `lib/providers`; use `StreamProvider` for live Firestore data, `autoDispose` for screen-scoped providers holding listeners.
- **Models**: define `fromJson`/`toJson` (or Firestore equivalents) with null-safe defaults — avoid `!` on Firestore document data.
- **Theming**: use `AppColors` and the existing dark theme rather than hardcoded colors.
- **Currency**: always go through `CurrencyFormatter`; the app supports PHP/USD/EUR via admin settings.
- **No server-side validation**: since there are no Cloud Functions, business-rule enforcement (loan interest, returns calc, payment limits) must be backed by `firestore.rules`, not just client logic.

## Key Files

- `firestore.rules` — security rules; review before changing any write path.
- `firestore.indexes.json` — required for any new compound Firestore query.
- `sinking_fund_logic.md` — domain logic reference (interest, returns, repayments).
- `sinking_fund_app.md` — app/feature overview.
- `analysis_options.yaml` — Dart analyzer config.
- `scripts/seed_emulator.dart` — seeds the Firestore emulator with known test data matching `sinking_fund_logic.md` examples.

## ⚠️ Spark Plan Constraints

This project is on the **Firebase Spark (free) plan**. Do NOT:
- Use **Cloud Functions** (no server-side logic)
- Use **Firebase Storage** (base64 fallback for receipts instead)
- Add any feature requiring a Blaze/Blaze plan service

All business-rule enforcement must be in `firestore.rules`, not Cloud Functions or client-only code.

## Target Platforms

- Android (8.0+)
- iOS
- Web (marketing site only)

## Debugging Setup

When debugging a reported issue, prefer **verification over inference** — run things and look at real output rather than reasoning from source alone.

### 1. Static analysis + tests first

Before forming a hypothesis about a Dart/Flutter bug, run:

```bash
flutter analyze
flutter test
```

If the bug has no failing test yet, **write one that reproduces it first** (in `test/`), confirm it fails for the expected reason, then fix until it passes. Don't mark a fix done without `flutter analyze` clean and `flutter test` passing.

### 2. Firebase Local Emulator Suite (for Firestore/rules/auth bugs)

Most real bugs in this app involve Firestore — permission-denied errors, missing indexes, wrong query results, rules misbehaving, or stream timing issues. The emulator lets you see the *actual* Firestore response instead of guessing from `firestore.rules`.

**Install** (one-time):
```bash
npm install -g firebase-tools
```

**Start emulators**:
```bash
firebase emulators:start --only firestore,auth
```

This uses the project's `firebase.json` config. Default ports: Firestore `8080`, Auth `9099`, Emulator UI `4000` (check `firebase.json` for actual configured ports).

**Point the app at the emulator** — when running `flutter run` for debugging, the app needs `useFirestoreEmulator`/`useAuthEmulator` calls (typically in `main.dart`, gated behind a debug flag or environment check). If this isn't already wired up, add it behind `kDebugMode` rather than hardcoding for all builds.

**Workflow for a Firestore/rules bug**:
1. Start the emulator.
2. Run `scripts/seed_emulator.dart` (see below) to populate known test data.
3. Reproduce the reported action (loan issuance, repayment, approval, etc.) against the emulator.
4. Read the actual error from the Emulator UI (`http://localhost:4000`) — for rules issues this shows exactly which `allow` clause failed and why.
5. Fix `firestore.rules` or the client code, re-run the same repro, confirm the error is gone.

**Workflow for a rules-only check** (no app needed):
```bash
firebase emulators:exec --only firestore "dart run scripts/seed_emulator.dart"
```
This starts the emulator, runs the script, and shuts down — good for quick repro without leaving emulators running.

### 3. Get the real error, not a paraphrase

Ask for (or capture) the full stack trace via `flutter logs` or the red error screen text verbatim — Dart stack traces point at the exact file/line/widget, which narrows the search dramatically compared to a symptom description like "the loan screen crashes."

### 4. Domain logic bugs (interest, balances, returns)

For bugs involving fund balance, loan interest, repayments, or returns:
1. Read `sinking_fund_logic.md` for the expected formula/edge case.
2. Use `scripts/seed_emulator.dart` to set up the exact scenario from the spec (or the user's reported numbers).
3. Run the relevant provider/computation against that seeded data and compare actual vs. expected per the formula.
4. If they diverge, the bug is in the implementation; if the spec itself doesn't cover the case (e.g. a new edge case), flag it and propose updating `sinking_fund_logic.md` too (see `CONTRIBUTING.md` → Domain Logic Changes).

## Notes for Agents

- This repo has no CI-configured test suite beyond `flutter test` / `test/` — run it after non-trivial Dart changes.
- Don't add Cloud Functions–dependent features without flagging that the project is on the Firebase Spark (free) plan.
- When touching Firestore queries, check `firestore.indexes.json` for a matching index or the query will fail in production.
- Admin role is currently determined by hardcoded email list — if changing auth/role logic, update both client checks and `firestore.rules` consistently.
