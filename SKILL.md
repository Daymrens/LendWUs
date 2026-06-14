---
name: lendwus-code-quality
description: Debug errors, review code quality, and improve the LendWUs app (Flutter/Dart mobile app with Riverpod + Firebase, plus a React/TypeScript marketing website). Use this skill whenever the user shares Dart/Flutter code, Riverpod providers, Firestore repositories, React/TS website code, build errors, stack traces, or crash logs from this project, or asks to debug, fix bugs, review code quality, refactor, optimize performance, audit Firestore rules/security, or generally "improve my app." Trigger even if the user doesn't explicitly say "debug" — e.g. "why isn't this working", "this screen is laggy", "clean this up", "is this safe", "check my rules". Always apply this skill's checklists before responding to any code from this repo.
---

# LendWUs Code Quality & Debugging

LendWUs is a family-circle sinking fund (paluwagan) app: group savings, loans, and returns tracking.

- **Mobile**: Flutter + Dart, Riverpod (providers + StreamProvider), go_router
- **Backend**: Firebase Auth (email + Google), Cloud Firestore, Firebase Hosting (Spark plan — **no Cloud Functions**)
- **Web**: React 18 + TypeScript marketing site, lucide-react icons
- **Structure**: `lib/core` (theme, utils, widgets), `lib/data/models`, `lib/data/repositories`, `lib/providers`, `lib/screens`

When the user shares code, errors, or asks for review/improvements, work through the relevant checklists below. Always be concrete: point to the specific file/line/widget/provider, explain *why* it's a problem, and give the corrected code.

## 1. Debugging Workflow

When given an error, stack trace, or "this isn't working":

1. **Identify the layer first**: UI (widget/screen), state (Riverpod provider), data (repository/Firestore), or build/tooling (pubspec, Gradle, Firebase config).
2. **Read the actual error message** — Flutter/Dart errors often point to the real cause several frames down (e.g. `LateInitializationError`, `type 'Null' is not a subtype of type 'X'`, `setState() called after dispose()`).
3. **Common LendWUs-shaped bugs to check first**:
   - **Null/type errors from Firestore** — `doc.data()!['field']` casts that assume a field exists; missing null checks on optional fields like receipt URLs.
   - **Riverpod issues** — using `ref.read` where `ref.watch` is needed (UI won't rebuild), `ref.watch` inside callbacks/`initState` (should be `ref.read`), disposing `StreamProvider`s improperly, `ref.listen` side effects placed in `build`.
   - **StreamProvider race conditions** — approvals/loans screens reading a stream before auth state resolves, causing permission-denied Firestore errors on first frame.
   - **go_router** — missing route guards (non-admin reaching admin routes), incorrect redirect logic causing infinite redirect loops.
   - **Currency/number formatting** — `CurrencyFormatter` mismatches between PHP/USD/EUR, integer division truncating interest calculations, floating point rounding on balances.
   - **Loan repayment math** — auto-calculated balances not accounting for partial payments or interest compounding order.
   - **Returns tracking** — division by zero when `heads == 0`; integer vs double division for "total interest ÷ heads."
4. **Reproduce mentally**: trace the data flow from Firestore document → repository → provider → widget. State which step breaks and why.
5. **Fix + explain**: give the corrected code, then a one-line explanation of the root cause (not just "added a null check").

## 2. Code Quality Review Checklist (Dart/Flutter)

When reviewing or improving Dart code, check for:

- **Riverpod correctness**: providers scoped appropriately (avoid global mutable state via `late` singletons); `autoDispose` used for screen-scoped providers that hold Firestore listeners to avoid leaks; `AsyncValue` handled with `.when()`/`.maybeWhen()` covering loading/error/data, not just `.value`.
- **Repository pattern**: Firestore CRUD isolated in `lib/data/repositories`, never called directly from widgets; queries use proper indexes (cross-check against `firestore.indexes.json`); writes use `FieldValue.serverTimestamp()` for audit fields, not client `DateTime.now()`.
- **Models**: `fromJson`/`toJson` (or `fromFirestore`/`toFirestore`) handle missing/null fields gracefully with defaults; avoid `!` (null assertion) on Firestore data — prefer `??` fallbacks.
- **Widget structure**: large screens broken into smaller widgets; `const` constructors used wherever possible; avoid rebuilding entire screens when only a sub-tree depends on a provider (use `Consumer`/`Selector` patterns).
- **Error handling/UX**: every async action (contribution submission, loan request, approval) shows loading state, success feedback, and a user-facing error message — never a silent failure or raw exception text.
- **Theming**: colors/spacing come from `AppColors`/theme, not hardcoded hex values scattered across screens.
- **Naming/consistency**: match existing naming conventions in `lib/data/models` and `lib/providers` (e.g. if other repos use `XxxRepository`, new code should too).

## 3. Firestore & Security Review

Since there are **no Cloud Functions** (Spark plan), all validation happens client-side + Firestore rules — review both:

- **firestore.rules**: every collection write should check `request.auth != null` and role (admin vs member); members should only write their own contribution/loan-request docs, not approve their own requests; admin email hardcoding (`act.drapor@gmail.com`, `daymrens@gmail.com`) should be reflected as a custom claim or role field check in rules, not assumed from client logic alone.
- **No server-side enforcement**: flag any business logic (interest calculation, returns computation, balance updates) that's done purely client-side and trusted by rules — a malicious client could write arbitrary values. Suggest rule-level range/field checks (e.g. `request.resource.data.amount is number && request.resource.data.amount > 0`).
- **firestore.indexes.json**: any new compound query (e.g. filter by member + date range) needs a matching index, or it'll fail at runtime in production even if it works in the emulator.

## 4. Performance Checklist

- **Firestore reads**: avoid re-fetching entire collections on every rebuild — use `StreamProvider` with `.snapshots()` and proper `autoDispose`/`keepAlive` based on screen lifecycle.
- **Lists**: use `ListView.builder`/`SliverList` for contributions/loan history, never `Column` with `.map()` over potentially large lists.
- **Images**: receipt uploads — confirm compression/resizing before upload to Firebase Storage equivalent (or Firestore base64, if used) to avoid large payloads.
- **fl_chart**: rebuilding chart widgets on every provider update — memoize data transforms (group-by-month aggregation) so they don't recompute on unrelated state changes.

## 5. React/TypeScript Website Checklist

For `website/src` (App.tsx, App.css, firebase.ts):

- **TypeScript strictness**: no `any` for Firebase config or component props; define interfaces for feature/section data (hero, feature grid, how-it-works steps) instead of inline object literals.
- **Responsiveness**: verify hamburger nav breakpoints match `App.css` media queries; check phone mockup and admin/member preview images have responsive sizing (no fixed px widths causing horizontal overflow on mobile).
- **Firebase config**: `firebase.ts` should not expose any keys beyond the standard public web config; confirm no admin SDK or service account usage on the client.
- **Accessibility**: lucide-react icons used purely decoratively need `aria-hidden`; interactive elements (nav links, APK download button) need accessible labels.
- **Build**: confirm `npm run build` output matches `firebase.json` hosting `public` directory before deploy.

## 6. Response Format

- For **debugging**: state the root cause first in one sentence, then show the fix as a diff or corrected snippet, then briefly explain why it happens.
- For **quality review**: group findings by severity — Bugs (will break/crash), Risks (security/data integrity), Improvements (style/perf/maintainability). Don't list every nit; prioritize the top 3-5 per category.
- For **"improve my app"** (open-ended): ask which area (mobile UI, Firestore/security, performance, website) if not specified, since this repo spans multiple stacks — unless the user has already shared specific code/files, in which case review what's in front of you.
- Always give corrected code in full, runnable snippets (not fragments requiring guesswork on imports/context).
