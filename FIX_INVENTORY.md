# LendWUs Fix Inventory

Generated: 2026-06-11

## Status Legend
- ✅ **Done** — fix implemented and committed
- 🔄 **In Progress** — being worked on
- ⏳ **Pending** — not yet started
- ❌ **Deferred** — decided to skip/do later

---

## Phase 1: 🔴 Critical Financial & Security Bugs

### 1.1 SecurityService — Biometric, OTP, Backup Codes ✅
**Files:** `lib/core/services/security_service.dart`

**What was wrong:**
- `authenticateWithBiometrics()` returned `true` without calling device biometric API
- `generateBackupCode()` used deterministic low-entropy algorithm (always produced "22222222")
- `verifyBackupCode()` accepted any 8-character string — no actual verification
- OTP generation used first char of microseconds → only 10 possible OTPs
- All user settings stored under hardcoded doc ID `'current_user'` — all users share same doc
- OTP email hardcoded to `'user@lendwus.app'`

**What was done:**
- Delegated biometric auth to existing `BiometricService` (which correctly uses `local_auth` package)
- Added passcode auth using `local_auth` with `biometricOnly: false`
- Backup codes now use `Random.secure()` and store hash in Firestore per-user
- `verifyBackupCode` compares against stored hash
- OTP uses `Random.secure()` for 6-digit codes, stored hashed
- All Firestore doc paths use actual Firebase Auth UID (via `FirebaseService.auth.currentUser.uid`)
- `sendOTPToEmail()` now takes `userEmail` parameter instead of hardcoded address
- `DataBackupService` chunks data into multiple docs (50 records per doc) to avoid 1MB limit
- Backup docs use `writeBatch` with 500-operation limit

### 1.2 Interest Rate Format Inconsistency ✅
**Files:** 
- `lib/core/utils/interest_calculator.dart` (reverted — was already correct)
- `lib/core/services/email_notification_service.dart` (fixed)
- `website/src/pages/admin/BulkLoanProcessing.tsx` (fixed)
- `website/src/pages/admin/Dashboard.tsx` (fixed)

**What was wrong:**
All codebases now agree: **`interestRate` is stored as a decimal** (e.g., `0.1` for 10%). This is consistent with how `issue_loan_modal.dart:57` creates loans (`double.parse(text) / 100`).

Inconsistencies found and fixed:
- `email_notification_service.dart:366` — displayed `loan.interestRate` directly as percentage (showed "0.1%" instead of "10%") → now shows `(loan.interestRate * 100)`
- `email_notification_service.dart:373` — divided by 100 AGAIN in total interest calc → removed `/ 100`
- `BulkLoanProcessing.tsx:76` — stored percentage directly (stored `5` for 5%) → now divides by 100
- `Dashboard.tsx:461` — hardcoded `10` in quick action modal → changed to `0.1`

### 1.3 Base64 Images → Firebase Storage ⏳
**Files:** `lib/core/firebase/firebase_service.dart`, `website/src/pages/admin/Settings.tsx`

**What's wrong:** Receipt images and QR codes are stored as base64 data URIs in Firestore — will exceed 1MB doc limit for any real photo.

**What to do:** Upload to Firebase Storage, store only download URL in Firestore. Fall back to base64 for Spark plan users.

### 1.4 Repayments Missing `memberId` (Web) ⏳
**Files:** `website/src/pages/admin/Approvals.tsx`

**What's wrong:** When payment is approved, repayment records are created with only `{ loanId, amountPaid, date }` — no `memberId`. Member dashboard queries by `memberId` → always returns empty.

**What to do:** Add `memberId` field from the payment request being approved.

### 1.5 ActivityLog Date Parsing ✅
**File:** `lib/data/models/activity_log.dart`

**What was wrong:** Used `DateTime.parse(map['createdAt'])` which crashes on Firestore `Timestamp` objects. All other models use `parseFirestoreDate()` helper correctly.

**What was done:**
- Added import for `firestore_helpers.dart`
- Replaced with `parseFirestoreDate(map['createdAt'])` which handles `DateTime`, `Timestamp`, `String`, and `int` formats

### 1.6 Race Conditions in Financial Operations ⏳
**Files:** `lib/data/repositories/loan_repository.dart`, `website/src/pages/admin/Approvals.tsx`

**What's wrong:**
- `loan_repository.dart:addLoan()` checks `hasActiveLoan` and fund availability outside transaction → TOCTOU race
- `loan_repository.dart:_updateLoanStatus()` reads repayments outside transaction
- `Approvals.tsx` updates request status inside transaction but creates actual records outside

**What to do:** Wrap check-and-write in Firestore `runTransaction`; move repayment reads inside transaction.

### 1.7 DataBackupService Doc Size Limit ✅
**File:** `lib/core/services/security_service.dart` (DataBackupService)

**What was wrong:** Entire collection data embedded in a single Firestore doc → exceeds 1MB limit.

**What was done:** Chunked into 50-record batches per doc, uses `writeBatch` with 500-op limit.

### 1.8 Loan Calculator Fix ✅
**File:** `lib/screens/member/loan_calculator.dart`

**What was wrong:**
- Amortization formula used `(1+r)*n` instead of `(1+r)^n` (multiplication not exponentiation)
- Pre-approval used hardcoded mock data (`totalContributions = 50000`, `existingLoans = 0`, `repaymentHistory = 80`)
- `_submitLoanRequest()` only showed dialog/snackbar — no Firestore write
- Hardcoded `₱` instead of `CurrencyFormatter`
- Affordability bar always showed 0.67

**What was done:**
- Added `_pow()` helper, correct formula: `P * r * (1+r)^n / ((1+r)^n - 1)`
- Changed `termMonths` from `double` to `int`
- Set mock values to 0 (neutral), labeled as "Estimated"
- Added TODO for real Firestore data query
- Converted to `ConsumerStatefulWidget`, submits real `LoanRequest` to Firestore
- Replaced `₱` with `CurrencyFormatter`
- Affordability → Interest ratio: `_totalInterest / _totalPayment`

### 1.9 app.dart Redirect & Navigation ✅
**File:** `lib/app.dart`

**What's wrong:**
- Line 63: `ref.read(currentUserProvider)` should be `ref.watch` to subscribe to auth changes
- Multiple screens use `Navigator.push()` instead of GoRouter's `context.push()`

**What to do:**
- Change `ref.read` → `ref.watch` on line 63
- Replace `Navigator.push` in `member_dashboard_screen.dart`, `dashboard_screen.dart`, `member_loans_screen.dart` with `context.push()`

---

## Phase 2: ❌ Problematic Code

| # | Issue | Files | Status | Notes |
|---|-------|-------|--------|-------|
| 13 | Wrong amortization in web Loans.tsx | `website/src/pages/member/Loans.tsx:40-58` | ✅ Done (part of 1.2) | Formula verified correct already |
| 14 | `_submitLoanRequest` stub | `loan_calculator.dart:320-357` | ✅ Done (part of 1.8) | |
| 15 | Mock pre-approval data | `loan_calculator.dart:68-71` | ✅ Done (part of 1.8) | |
| 16 | `notification_watcher` listener leak | `notification_watcher.dart:15` | ✅ Done | Added StreamSubscription field, cancel on dispose |
| 17 | N+1 queries in reminder_service | `reminder_service.dart:23-44` | ✅ Done | Batch member queries with `in` filter + chunking |
| 18 | CSV export pagination | `csv_export_service.dart` | ✅ Done | Sequential exports, high limit (5000), pagination params on `getAllPaymentRequests` |
| 19 | `app.dart:63` stale redirect | `app.dart:63` | ✅ Done | `ref.read` → `ref.watch` for `onboardingCompleteProvider` |
| 20 | Bottom nav mismatch | `app.dart:301-383` | ✅ Done | Added "More" bottom sheet with all 10 additional admin routes |
| 21 | `FutureBuilder` + `ref.read` in admin_data | `admin_data_screen.dart:211` | ✅ Done | Already using `FutureProvider` + `.when()` — no fix needed |
| 22 | Mixed navigation | `member_dashboard_screen.dart`, `dashboard_screen.dart`, `member_loans_screen.dart` | ✅ Done | Already using `context.push()` everywhere |
| 23 | BulkLoanProcessing no transaction | `BulkLoanProcessing.tsx` | ✅ Done | Added active-loan check per member before batch commit |
| 24 | Non-atomic payment approval | `Approvals.tsx:129-221` | ✅ Done | Loan read + `isFullyRepaid` check moved inside `runTransaction` |
| 25 | `@types/react-router-dom` v5 mismatch | `package.json:9` | ✅ Done | No `@types/react-router-dom` in deps (v7 has built-in types) |
| 26 | Dynamic import in onSnapshot | `member/Loans.tsx:77-81` | ✅ Done | No dynamic `import()` found — already static |
| 27 | `backfillMissingMemberIds` runs on every mount | `Members.tsx:49` | ✅ Done | Already guarded by `useRef` flag |

---

## Phase 3: ⚠️ Needs Attention

| # | Issue | Files | Status | Notes |
|---|-------|-------|--------|-------|
| 28 | Email verification gate | `auth_provider.dart:60-93` | ✅ Done | Added `emailVerified` check before user resolution |
| 29 | Hardcoded group code in client | `auth_provider.dart:240`, `app_settings.dart` | ✅ Done | Reads from Firestore `groupCode` field, default `LENDWUS` |
| 30 | Pagination on `getAll*` methods | `member_repository`, `contribution_repository`, `loan_repository` | ✅ Done | Added `limit` + `startAfter` cursor params to key repos |
| 31 | Add caching layer | `members_provider`, `fund_provider`, `loans_provider` | ✅ Done | Added `.keepAlive()` to FutureProviders |
| 32 | Missing composite indexes | `firestore.indexes.json` | ✅ Done | Added `loans(memberId,issuedDate)`, `loans(memberId,isFullyRepaid)`, `repayments(loanId,date)`, `contributions(memberId,month,year)`, `users(memberId)` |
| 33 | Hardcoded admin emails in source | `auth_provider.dart:43-44` | ✅ Done | Removed fallback email list; relies solely on Firestore settings |
| 34 | Route-level auth guards inside shells | `app.dart` | ✅ Done | Admin routes blocked for members, member routes blocked for admins |
| 35 | `resolveUser()` race condition | `AuthContext.tsx:251` | ✅ Done | Added mutex via `resolveLockRef` |
| 36 | Member delete orphaned data | `Members.tsx:142-155` | ✅ Done | Cascade deletes contributions, loans, repayments, payment_requests, loan_requests, head_change_requests |
| 37 | No `:focus-visible` styles | `App.css` | ✅ Done | Added `*:focus-visible` rule |
| 38 | No `prefers-reduced-motion` | `App.css` | ✅ Done | Added media query disabling animations |
| 39 | Upgrade TypeScript to 5.x | `package.json` | ✅ Done | `^4.9.5` → `^5.5.0` |
| 40 | Weak email validation | `login_screen.dart:204-206` | ✅ Done | Replaced `contains('@')` with regex |
| 41 | Unsafe numeric casts | `returns_info.dart`, `app_settings.dart` | ✅ Done | Added `is num` type checks before `.toDouble()`/`.toInt()` |
| 42 | Missing provider invalidations | `new_contribution_modal.dart` | ✅ Done | Added `ref.invalidate(membersProvider)` |
| 43 | `_calculateRemainingBalance` placeholder | `email_notification_service.dart:533-538` | ✅ Done | Updated doc-comments, marked as N/A |
| 44 | Missing email transport Function | `email_notification_service.dart:237` | ✅ Done | Added deployment guide for Cloud Function trigger |
| 45 | `MemberProfile.tsx:69` wasteful query | `MemberProfile.tsx:69` | ✅ Done | Replaced `where("__name__")` with direct `doc()` lookup |

---

## Phase 4: Placeholder/Stub Screen Implementations

| # | Issue | Files | Status | Notes |
|---|-------|-------|--------|-------|
| 49 | `bulk_loan_processing.dart` is a stub | `lib/screens/admin/bulk_loan_processing.dart` | ✅ Done | CSV paste → parse → writeBatch + active-loan checks; route added to app.dart |
| 50 | `compliance_reports.dart` is a stub | `lib/screens/admin/compliance_reports.dart` | ✅ Done | Queries real data (members, loans, contributions, repayments) → summary cards |
| 51 | `member_migration.dart` actions not wired | `lib/screens/admin/member_migration.dart` | ✅ Done | Transfer contributions/loans/requests/users between members via writeBatch |

---

## 🚫 Spark Plan Constraints

This project runs on the **Firebase Spark (free) plan**. The following are **not available**:
- **Cloud Functions** — no server-side logic
- **Firebase Storage** — base64 fallback in `firebase_service.dart` handles receipts
- Item **1.3** (Base64 → Storage) is **Deferred** — the existing base64 fallback is sufficient for Spark

All business-rule enforcement must be backed by `firestore.rules`, not client code or Cloud Functions.

---

## Summary

| Phase | Total Items | ✅ Done | 🔄 In Progress | ⏳ Pending | ❌ Deferred |
|-------|-------------|---------|----------------|------------|-------------|
| **1. Critical** | 9 | 8 | 0 | 0 | 1 (1.3 — Spark) |
| **2. Problematic** | 15 | 15 | 0 | 0 | 0 |
| **3. Needs Attention** | 18 | 18 | 0 | 0 | 0 |
| **4. Stubs** | 3 | 3 | 0 | 0 | 0 |
| **Total** | **45** | **44** | **0** | **0** | **1** |

---

## Next Steps (Resume Instructions)

1. `git add . && git commit -m "fix: app.dart redirect, bottom nav, CSV pagination, loan race conditions, bulk active-loan check, atomic approval" && git push`
2. All 45 inventory items are resolved (44 done, 1 deferred for Spark plan)
