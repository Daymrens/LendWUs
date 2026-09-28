# LendWUs — Technical Audit & Fix-List Spec

**Source reviewed:** https://github.com/Daymrens/LendWUs (branch: `master`)
**Scope:** Full repo — `lib/`, `firestore.rules`, `sinking_fund_logic.md`, `AGENTS.md`, `pubspec.yaml`, `test/`
**Purpose:** Prioritized fix list for an AI coding agent (opencode/Kiro/Windsurf) to work through. Each item names the exact file(s) involved so the agent doesn't need to re-discover context.

---

## How to use this doc

Items are ordered by priority (P0 = fix before anything else touches money or user data, P3 = nice-to-have / decide-and-document). Each item has:
- **Where** — exact file(s)
- **Problem** — what's actually wrong, grounded in the code
- **Fix** — concrete next step
- **Why it matters** — so the agent doesn't "fix" it into something worse

---

## P0 — Financial correctness bugs (real money can end up wrong)

### 1. Payment approval isn't atomic → duplicate-contribution bug on retry

**Where:** `lib/data/repositories/payment_request_repository.dart` → `approvePaymentRequest()`

**Problem:** `AGENTS.md` states the contribution-doc-create + status-update "should happen in a single batch... since there are no Cloud Functions to guarantee this server-side." The actual implementation does NOT batch it:
1. Transaction flips `payment_requests.status` to `'approved'`
2. Separately: creates a `contributions` doc
3. Separately: queries all this-month contributions for the member
4. Separately: reads and updates `members.balance`

If the app loses connection or crashes between steps 2–4, the `catch` block reverts `status` back to `'pending'` — but any writes that already landed (the contribution doc, the balance update) **stay**. If the admin retries the approval afterward, step 2 runs again and creates a **second contribution doc for the same payment** — a real duplicate credit in the ledger.

**Fix:**
- Wrap steps 2–4 in a single Firestore `WriteBatch` (or a transaction if all reads/writes fit Firestore's transaction constraints — note transactions can't run arbitrary collection queries, so a batch is more realistic here) so it's all-or-nothing.
- Before creating the contribution doc, check whether a contribution already exists for this `payment_requests` doc ID (e.g. store `sourceRequestId` on the `Contribution` model and query for it) so a retry after partial failure is idempotent instead of duplicating.

**Why it matters:** This is the single highest-impact bug in the repo — it's a live path to double-crediting a member's contribution, which throws off `fundBalance`, `totalContributions`, and every downstream report.

---

### 2. Loan issuance race condition (self-documented, not yet fixed)

**Where:** `lib/data/repositories/loan_repository.dart` → `addLoan()`

**Problem:** The code comments already admit this: the "member has no active loan" check (`hasActiveLoan`) is a query run *outside* the transaction, because Firestore transactions can't run collection queries. Two concurrent loan approvals for the same member can both pass the check and both create a loan. Similarly, nothing enforces `principal ≤ availableToLoan` transactionally — `sinking_fund_logic.md` §3 specifies this rule, but it isn't enforced atomically anywhere.

**Fix:**
- Add a `hasPendingLoanClaim` marker doc (e.g. `loan_claims/{memberId}`) written inside the same transaction as loan creation, checked via `txn.get()` (a single-doc read is transaction-safe, unlike a collection query). This turns "does this member already have a loan" into a transaction-safe check.
- Alternatively, since admin approvals are already a manual, low-frequency action, a simpler mitigation is a client-side advisory lock (disable the approve button + re-check state after a short delay) — cheaper to build, doesn't fully close the race, but is proportionate for a family-circle admin UI vs. a full data-model change.

**Why it matters:** Currently undocumented as "won't fix" anywhere except a code comment. Decide explicitly whether this is acceptable risk for the intended scale (a handful of admins, infrequent loan issuance) or worth the transaction-marker fix.

---

### 3. Currency stored as floating-point `double`, despite a centavos-safe API already existing unused

**Where:**
- Models storing money as `double`: `lib/data/models/loan.dart`, `member.dart`, `contribution.dart`, `repayment.dart`
- Unused safer API already written: `lib/core/utils/currency_formatter.dart` (`toCentavos`, `formatCentavos`, `parse() → int`)
- Acknowledged in `sinking_fund_logic.md` §12: *"the sum of member shares may differ from totalInterestEarned by a small rounding amount... this is an accepted approximation."*

**Problem:** IEEE-754 float math accumulates rounding error over many contributions/repayments/returns computations. The fix for this (integer centavos) is already written in `CurrencyFormatter` but the actual data models never adopted it.

**Fix:** Migrate `principal`, `balance`, `amount`, `amountPaid`, `amountPerHead`, `totalRequired` to `int` centavos across all models, repositories, and calculators (`interest_calculator.dart`, `growth_spots_calculator.dart`). This is a real migration (models, Firestore documents, and every screen that formats currency), not a small patch — scope it as its own task.

**Why it matters:** Rounding drift compounds silently. For a fund making end-of-year returns calculations (§12) across many members, small errors can become visible ("why don't the shares add up to the total?").

---

## P0 — Features that are advertised but structurally do nothing

### 4. Email notifications never actually send

**Where:** `lib/core/services/email_notification_service.dart`, all five send methods (`sendWelcomeEmail`, `sendMonthlyReportEmail`, `sendPaymentConfirmationEmail`, `sendLoanApprovalEmail`, `sendRepaymentConfirmationEmail`) → all route through `_sendEmail()`

**Problem:** `_sendEmail()` writes a doc to `email_logs` with `status: 'sent'` and prints to console. The method's own comment admits: *"A Firebase Cloud Function... must read documents from this collection and actually dispatch the emails."* But `AGENTS.md` explicitly forbids Cloud Functions on the Spark plan. **No Cloud Function exists in this repo.** Nothing has ever sent an email. This includes `sendWelcomeEmail`, which is meant to deliver a member's temporary password.

**Fix — pick one:**
- **(a) Wire up real delivery without Cloud Functions:** call a transactional email API (Resend, SendGrid, Postmark) directly from the Flutter client using their HTTP API + an API key. This is not ideal (API key shipped in-app, needs to be a restricted/scoped key) but is Spark-plan compatible and genuinely sends email. A slightly safer variant: a tiny external endpoint you host yourself (e.g. a free-tier Cloudflare Worker) that holds the real API key and only accepts calls from your app.
- **(b) Upgrade to Firebase Blaze (still free at low volume) and add one Cloud Function** that watches `email_logs` and dispatches via nodemailer/SendGrid — this is literally what the code comment already describes; it just doesn't exist yet.
- **(c) If neither is worth building right now:** remove or clearly gray out the email-dependent UI (e.g. don't promise "welcome email sent" in the member-creation flow) so nothing implies a delivery that isn't happening.

**Why it matters:** Right now the app silently lies about this in at least one security-relevant flow (temporary passwords).

---

### 5. Push notifications don't reach closed/backgrounded apps

**Where:** `lib/core/services/notification_service.dart` (receiving side, fully built) vs. `lib/data/repositories/notification_repository.dart` (`notifyAdmins`, `notifyMember`, `notifyAll`, etc. — sending side)

**Problem:** The repository's "notify" functions only write to the Firestore `notifications` collection. There is no call to the FCM send API anywhere in the repo. `notification_service.dart` is fully wired to *receive* a push if one arrives, but nothing ever sends one. In practice: a member only sees a notification if they open the app while online (Firestore stream) — not as an actual push when the app is closed.

**Fix:** Same fork as item 4 — either add a small server component (Cloud Function on Blaze, or an external webhook you control) that reads new `notifications` docs and calls the FCM v1 API with a service-account credential (never ship this key in the client), or explicitly scope this as "in-app notification center only, no push" in the feature list until that's built.

**Why it matters:** For a lending app, "your payment was rejected" or "your loan is due" arriving only if the member happens to open the app is a meaningfully different (weaker) guarantee than what "push notifications" implies to users.

---

### 6. "Auto backup" isn't automatic, and isn't really a backup

**Where:** `lib/core/services/security_service.dart` → `DataBackupService` (`backupData`, `scheduleAutoBackup`, `cleanupOldBackups`)

**Problem:** `scheduleAutoBackup()` only writes a settings doc claiming a daily schedule — nothing triggers it without a human opening the app and calling `backupData()` manually (no Cloud Scheduler / Cloud Functions available). Additionally, `backupData()` copies collections into a `backups` collection **inside the same Firestore project**, which isn't disaster recovery — if the project or the admin's account is compromised, the "backup" is compromised too.

**Fix:**
- Rename/reframe this feature honestly as "manual snapshot" until real automation exists.
- For actual DR, export outside the project — e.g. a periodic client-triggered export to a file the admin downloads/stores elsewhere (Google Drive, email-to-self), since Cloud Storage export APIs typically need Blaze.

**Why it matters:** An admin relying on "auto backup" to protect fund records could discover, only when they need it, that nothing was ever actually scheduled or off-site.

---

### 7. Payment/loan reminders require manual trigger

**Where:** `lib/core/services/reminder_service.dart` → `sendPaymentReminders()`

**Problem:** Same root cause as above — no Cloud Scheduler on Spark plan, so reminders only run if someone opens the app and triggers this function.

**Fix:** Either accept this as "admin taps a 'send reminders' button" and label it that way in the UI, or move to Blaze + a scheduled Cloud Function if automated daily reminders are actually needed.

---

## P1 — Security gaps in `firestore.rules`

### 8. Any member can write a notification into anyone else's inbox

**Where:** `firestore.rules`, `match /notifications/{notificationId}` → `allow create: if isAuth();`

**Problem:** No check that the notification's `userId` field matches the creator. Any authenticated member can create a notification doc targeting any other user.

**Fix:** `allow create: if isAuth() && request.resource.data.userId == request.auth.uid;` for member-authored notifications, with a separate allowance for admin-authored ones (`isAdmin()`).

---

### 9. Any authenticated user can corrupt the shared member-ID counter

**Where:** `firestore.rules`, `match /meta/member_counter` → `allow write: if isAuth() && ...` (only shape-validated, not role-validated)

**Problem:** Only checks `lastNumber is int` and range — doesn't require `isAdmin()`. Any signed-in member can overwrite the counter, causing member-ID collisions.

**Fix:** Add `isAdmin() &&` to the write condition, or move member-ID assignment into an admin-only write path entirely.

---

### 10. `members` collection is fully readable by any authenticated user

**Where:** `firestore.rules`, `match /members/{memberId}` → `allow read: if isAuth();`

**Problem:** Every member can read every other member's full document — `contactNumber`, `linkedEmail`, balance, etc. — with no scoping. May be an intentional choice for a small family circle; flagging so it's a deliberate decision rather than a default.

**Fix:** If intentional, document it as such (e.g. a comment in `firestore.rules`). If not, scope reads to `canReadMemberData(memberId)` like most other collections already do.

---

### 11. OTP and backup-code "hashing" isn't cryptographic

**Where:** `lib/core/services/security_service.dart` → `_hashCode()`, `_hashOTP()`

**Problem:** Both use a hand-rolled polynomial rolling hash (`hash = 31 * hash + charCode`) — fast, non-cryptographic, and collision-prone. Practical exposure is limited (only the doc owner can read their own hashed code per the rules), but it's presenting itself as a security control without being one.

**Fix:** Use a real digest (e.g. `crypto` package's `sha256`) even for this low-stakes case — it's a one-line swap and removes any question about it later.

---

## P2 — Structural limitations worth deciding on explicitly

### 12. Receipts stored as base64 directly in Firestore documents

**Where:** `lib/core/services/storage_service.dart` → `uploadReceipt()`

**Problem:** Spark plan has no Cloud Storage, so receipts are base64-encoded into the document itself. Firestore has a **1 MiB hard limit per document**. A typical phone camera JPEG can exceed that unless compressed/downscaled first. Also bloats every read of a contribution list (full image blob pulled every time).

**Fix:**
- Confirm `image_picker` (already a dependency) is configured with a low `imageQuality` and a `maxWidth`/`maxHeight` cap before the bytes ever reach `uploadReceipt()`.
- Consider storing a thumbnail inline and the full-res image elsewhere if higher fidelity is ever needed (would require Blaze + Cloud Storage).

---

### 13. `groups` collection is dead code — app is architecturally single-tenant

**Where:** `firestore.rules` → `match /groups/{groupId}` (hardcoded to `admin001@lendwus.app`); no `groupId` reference anywhere in `lib/`

**Problem:** This rule implies multi-tenancy (multiple separate paluwagan groups in one deployment) that doesn't exist anywhere in the actual app logic. It's either leftover from an earlier plan or aspirational scaffolding.

**Fix:** Either remove the rule (if there's no near-term plan for multi-tenancy) or treat "add `groupId` to every collection + rule" as its own explicit project if you ever want other families/orgs to run their own instance of this app from one codebase.

---

### 14. Loan interest model is flat one-time simple interest

**Where:** `lib/core/utils/interest_calculator.dart` (`principal + principal * interestRate`, applied once regardless of term)

**Problem:** Not wrong for an informal family paluwagan — but if this is positioned publicly as a general "lending app," most people will assume reducing-balance/amortized interest. Worth being explicit about this design choice wherever the app is described publicly.

**Fix:** No code change required — just make sure the app-store listing / description doesn't imply amortized lending if it isn't.

---

## P3 — Missing features common to "lending apps" (context-dependent, not necessarily needed)

These aren't bugs — they're gaps relative to what "lending app" implies to a general audience. Decide per-item whether they're in scope given this is a closed family/friend-circle tool, not a public lending platform:

- No loan agreement / acknowledgment step before disbursal
- No KYC/identity verification (fine for a closed circle, not for a public product)
- No credit history/risk scoring across cycles (who paid late before)
- No persisted "overdue" status on `Loan` — `dueDate` exists but overdue state appears to be computed at display time only, with no escalation
- No penalty/late-fee logic

---

## Regulatory note (not a code fix — just awareness)

If this app is ever distributed for use **outside** a single closed family/friend circle — i.e. other unrelated groups installing it to lend to each other with interest — the Philippines' **Lending Company Regulation Act (R.A. 9474)** requires SEC registration for entities extending credit to the public. A private family paluwagan is normally exempt in practice. Worth a quick check of current SEC guidance before any wider launch beyond your own circle; not a blocker for an app-store listing today.

---

## Suggested execution order

1. Item 1 (duplicate-contribution bug) — real money correctness, fix first
2. Items 4–7 (fake email/push/backup/reminders) — decide honest scope, then either build or relabel
3. Items 8–11 (rules hardening) — cheap, mechanical fixes
4. Item 2 (loan race condition) — decide risk tolerance given actual usage scale
5. Item 12 (receipt compression) — quick check, likely quick fix
6. Items 3, 13, 14 — larger decisions, scope as separate tasks if pursued
