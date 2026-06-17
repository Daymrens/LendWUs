# Firestore Schema — LendWUs

Project: `lmsystemm`. NoSQL (Cloud Firestore). No Cloud Functions (Spark plan) — all enforcement is client-side + `firestore.rules`.

Source of truth for field names/types: `lib/data/models/*.dart` — verify there first before relying on this doc for code changes.

---

## `users/{userId}`

Auth-linked user record (one per Firebase Auth UID).

| Field       | Type   | Notes                                              |
| ----------- | ------ | -------------------------------------------------- |
| `role`      | string | `'admin'` or `'member'`                            |
| `memberId`  | string | Links this auth user to a `members` document       |
| `username`  | string | Display name                                        |
| `email`     | string | Auth email                                          |
| `photoUrl`  | string?| Profile photo URL                                   |
| `fcmToken`  | string?| Push notification token                             |
| `isTreasurer`| bool? | Treasurer flag; set via `treasurerEmails` in settings |
| `createdAt` | string | ISO 8601 timestamp                                  |

**Access**:
- Create: owner or admin
- Read: owner, admin, or any user whose own `role == 'admin'`
- Update: owner or admin
- Delete / List: admin only

---

## `members/{memberId}`

A participant in the fund. Can hold 1+ "heads" (contribution shares).

| Field           | Type    | Notes                                                        |
| --------------- | ------- | ------------------------------------------------------------- |
| `name`          | string  | Required, non-empty                                             |
| `memberId`      | string? | Sequential ID like `LWS000001`                                  |
| `headsCount`    | int     | ≥ 1                                                             |
| `amountPerHead` | double  | e.g. `150.0` (NOT centavos — stored as decimal)                |
| `totalRequired` | double  | `headsCount * amountPerHead`                                    |
| `balance`       | double  | Credit balance (advance payments)                               |
| `avatarPath`    | string? | Avatar URL                                                     |
| `isActive`      | bool    | Inactive members can't contribute or borrow (client-side only)  |
| `linkedEmail`   | string? | Email used to self-link via `isMemberByLinkedEmail()`           |
| `joinedAt`      | string  | ISO 8601 timestamp                                              |

> **Note**: `firestore.rules` do NOT enforce `isActive` — the restriction is client-side only in `auth_provider.dart` and `issue_loan_modal.dart`.

**Access**:
- Create: any authenticated user (self-onboarding via group code `LENDWUS`)
- Read: any authenticated user
- Update / Delete: admin only

> Deleting a member with an active (not fully repaid) loan should be blocked at the app layer — see `sinking_fund_logic.md` §11.

---

## `contributions/{contributionId}`

A payment made by a member toward their head quota.

| Field       | Type      | Notes                                  |
| ----------- | --------- | ---------------------------------------- |
| `memberId`  | string    | Reference to `members/{memberId}`        |
| `amount`    | double    | NOT centavos — stored as decimal         |
| `date`      | string    | ISO 8601 timestamp                       |
| `month`     | int       | Extraction of `date.month` for queries   |
| `year`      | int       | Extraction of `date.year` for queries    |
| `receiptUrl`| string?   | Copied from `payment_requests` on approval |
| `notes`     | string?   | Optional notes                           |
| `createdBy` | string?   | `'admin'` or member ID                   |

> **Note**: `receiptUrl` is stored on the `payment_requests` doc before approval, and copied to the resulting `contributions` doc on approval for permanent record.

**Access**:
- Create: admin only
- Read: anyone who can read the related member's data (`canReadMemberData`)
- Update / Delete: admin only

---

## `payment_requests/{requestId}`

A member-submitted contribution or loan repayment that's pending admin approval. Supports two types (`type` field).

| Field          | Type      | Notes                                               |
| -------------- | --------- | ----------------------------------------------------- |
| `memberId`     | string    | Must match the requesting member (on create)          |
| `loanId`       | string?   | Set only for `type == 'loan'` (repayment requests)    |
| `type`         | string    | `'contribution'` \| `'loan'`                         |
| `amount`       | double    | NOT centavos                                          |
| `receiptPath`  | string?   | Local file path (client-only, not in Firestore)       |
| `receiptUrl`   | string?   | Uploaded receipt URL / base64 data                     |
| `receiptFilename` | string? | Original filename (website-only)                      |
| `status`       | string    | `'pending'` \| `'approved'` \| `'rejected'`          |
| `requestDate`  | timestamp | Creation timestamp (serves as `createdAt`)             |
| `approvedDate` | timestamp?| Set on approve/reject                                  |
| `approvedBy`   | string?   | Admin who approved                                     |
| `month`        | int?      | Month of request (website-only)                        |
| `year`         | int?      | Year of request (website-only)                         |
| `notes`        | string?   | Admin notes                                            |
| `rejectReason` | string?   | Reason for rejection                                   |
| `bankConfirmed`| bool?     | Treasurer has confirmed bank receipt                   |
| `bankConfirmedAt`| timestamp?| When treasurer confirmed                              |
| `bankConfirmedBy`| string?  | Treasurer's auth UID who confirmed                     |

**Access**:
- Create: the member themselves (`isMemberOf`), or admin
- Read: anyone who can read the related member's data, **or** any treasurer (`isTreasurer()`)
- Update: admin only (approval workflow) **except** treasurers may set `bankConfirmed`/`bankConfirmedAt`/`bankConfirmedBy` (for treasurer-based confirmation before admin approval)

> Approving a `type == 'contribution'` request should create a corresponding `contributions` doc; approving `type == 'loan'` creates a `repayments` doc. Both writes should happen atomically (batch write) — client-driven, no Functions.

---

## `loan_requests/{requestId}`

A member-submitted loan request pending admin approval.

| Field          | Type      | Notes                                               |
| -------------- | --------- | ----------------------------------------------------- |
| `memberId`     | string    | Must match requesting member                         |
| `memberName`   | string    | Denormalized for display                              |
| `amount`       | double    | NOT `principal` — stored as decimal, NOT centavos    |
| `interestRate` | double    | e.g. `5.0` = 5% (stored as whole percentage)         |
| `dueDate`      | string    | ISO 8601 timestamp (must be in future at issue time) |
| `status`       | string    | `'pending'` \| `'approved'` \| `'rejected'` \| `'disbursed'` |
| `requestedAt`  | timestamp | Creation timestamp (serves as `createdAt`)            |
| `processedAt`  | timestamp?| Timestamp of approval/rejection                       |
| `notes`        | string?   | Admin notes                                            |
| `loanId`       | string?   | Set to the created `loans/{loanId}` on approval       |

**Access**:
- Create: only the member themselves (`isMemberOf`) — admins cannot create on a member's behalf via this collection
- Read: anyone who can read the related member's data
- Update / Delete: admin only

> On approval, the `Loan` is created with `interestRate / 100` (converted from whole-percentage to decimal). The `loan_requests` doc is updated to `status: 'disbursed'` with a reference to the new loan.

---

## `loans/{loanId}`

An issued loan (created by admin, typically from an approved `loan_request`).

| Field            | Type      | Notes                                                          |
| ---------------- | --------- | ----------------------------------------------------------------- |
| `memberId`       | string    | Borrower reference                                                  |
| `principal`      | double    | NOT centavos — stored as decimal                                    |
| `interestRate`   | double    | e.g. `0.05` = 5% simple interest (stored as decimal)               |
| `issuedDate`     | string    | ISO 8601 timestamp                                                  |
| `dueDate`        | string    | ISO 8601 timestamp; must be in the future at issuance               |
| `isFullyRepaid`  | bool      | Set to `true` when `remainingBalance <= 0`                          |

Derived fields (computed client-side, not stored):
```
totalAmountDue     = principal + (principal * interestRate)
interestAmount     = principal * interestRate
totalRepaid        = sum of repayments where repayments.loanId == loanId
remainingBalance   = totalAmountDue - totalRepaid
interestPortion    = max(0, totalRepaid - principal)
```

**Access**:
- Create: admin only
- Read: anyone who can read the related member's data
- Update / Delete: admin only

**Validation rules** (enforce client-side — see `sinking_fund_logic.md` §3, §8):
- Borrower must be an active member
- `principal <= availableToLoan`
- Member must have no existing unpaid loan (one active loan at a time)
- `principal > 0`, `dueDate > today`

---

## `repayments/{repaymentId}`

A payment made by a borrower toward an outstanding loan.

| Field       | Type      | Notes                              |
| ----------- | --------- | ------------------------------------ |
| `loanId`    | string    | Reference to `loans/{loanId}`        |
| `amountPaid`| double    | NOT centavos — stored as decimal     |
| `date`      | string    | ISO 8601 timestamp                   |

Derived: `interestPortion = max(0, totalRepaid - principal)` — interest is recognized as earned once cumulative repayments exceed principal (`sinking_fund_logic.md` §7).

**Access**:
- Create: admin only
- Read: admin, or any user who can read the data of the member who owns the referenced loan (resolved via `loans/{loanId}.memberId`)
- Update / Delete: admin only

**Validation**: `amountPaid > 0` ; overpayment (`amountPaid > remainingBalance`) warns and credits excess.

---

## `app_settings/{settingId}`

Admin-configurable app-wide settings. Known doc: `app_settings/fund_settings`.

| Field                | Type           | Notes                                                |
| -------------------- | -------------- | ------------------------------------------------------ |
| `adminEmails`        | array\<string> | Emails granted admin access via `isAdmin()` rule check  |
| `treasurerEmails`    | array\<string> | Emails granted treasurer access via `isTreasurer()` rule check |
| `currencySymbol`     | string         | `'₱'` \| `'$'` \| `'€'`                                |
| `currencyCode`       | string         | `'PHP'` \| `'USD'` \| `'EUR'`                          |
| `loanInterestPercent`| double         | Default interest rate as whole percentage (e.g. `10.0`)|
| `minPaymentPerHead`  | double         | Minimum per-head contribution                           |
| `maxPaymentPerHead`  | double         | Maximum per-head contribution                           |
| `cutoffDay1`         | int            | First cutoff day (default `13`)                         |
| `cutoffDay2`         | int            | Second cutoff day (default `28`)                        |
| `paymentTatHours`    | int            | Payment turnaround hours (default `24`)                 |
| `qrAccountName`      | string         | QR payment account name                                 |
| `qrAccountNumber`    | string         | QR payment account number                               |
| `qrImageUrl`         | string         | QR code image URL / base64 data                         |
| `apkDownloadUrl`     | string         | APK download link                                       |
| `apkVersion`         | string         | Latest APK version                                      |
| `downloadCount`      | int            | APK download counter                                    |
| `contactEmail`       | string         | Support email                                           |
| `contactPhone`       | string         | Support phone                                           |
| `groupCode`          | string         | Self-onboarding group code (default `'LENDWUS'`)        |
| `isMaintenanceMode`  | bool           | App maintenance flag                                    |
| `maintenanceMessage` | string         | Message shown in maintenance mode                       |

**Access**:
- Read: any authenticated user
- Create / Update / Delete: admin only

> `adminEmails` here is one of two admin-detection paths (the other is `users/{uid}.role == 'admin'`). Both are checked by `isAdmin()` in `firestore.rules`.

---

## `head_change_requests/{requestId}`

A member-submitted request to change their number of contribution heads.

| Field            | Type      | Notes                                    |
| ---------------- | --------- | ------------------------------------------ |
| `memberId`       | string    | Must match requesting member               |
| `memberName`     | string    | Denormalized for display                    |
| `currentHeads`   | int       | Current head count at time of request       |
| `requestedHeads` | int       | New head count requested                    |
| `reason`         | string?   | Reason for change                           |
| `status`         | string    | `'pending'` \| `'approved'` \| `'rejected'`|
| `requestedAt`    | timestamp | Creation timestamp                          |
| `processedAt`    | timestamp?| Timestamp of approval/rejection             |
| `processedBy`    | string?   | Admin who processed                         |
| `notes`          | string?   | Admin notes                                 |

**Access**:
- Create: only the member themselves (`isMemberOf`)
- Read: anyone who can read the related member's data
- Update / Delete: admin only

> Approving this should update `members/{memberId}.headsCount` — client-driven, no Functions.

---

## `returns/{docId}`

End-of-year return computations (total interest ÷ heads, per-member share).

| Field        | Type   | Notes                                          |
| ------------ | ------ | -------------------------------------------------|
| `totalReturns` | double | Total interest earned (NOT `totalInterestEarned`) |
| `totalHeads` | int    | Sum of all active members' `headsCount`           |
| `perHeadShare` | double | `totalReturns / totalHeads` (rounded)           |

> Fields written to Firestore may differ from the model — check `returns_info.dart` and `returns_provider.dart` for the actual write structure.

**Access**:
- Read: any authenticated user
- Create / Update / Delete: admin only

> Guard against `totalHeads == 0` (division by zero) before computing `perHeadShare`.

---

## `loan_receipts/{receiptId}`

Generated loan receipt records (two per loan: one for admin, one for borrower). Created during loan approval in the website admin panel.

| Field            | Type      | Notes                                               |
| ---------------- | --------- | ----------------------------------------------------- |
| `loanId`         | string    | Reference to `loans/{loanId}`                         |
| `receiptNumber`  | string    | e.g. `LR-202606-00001`                                |
| `memberId`       | string    | Borrower reference                                     |
| `memberName`     | string    | Denormalized borrower name                             |
| `principal`      | double    | Loan principal                                         |
| `interestRate`   | double    | Decimal (e.g. `0.05` = 5%)                             |
| `interestAmount` | double    | `principal * interestRate`                             |
| `totalAmountDue` | double    | `principal + interestAmount`                           |
| `issuedDate`     | timestamp |                                                       |
| `dueDate`        | timestamp |                                                       |
| `status`         | string    | `'active'` initially                                   |
| `copyFor`        | string    | `'admin'` \| `'borrower'`                             |
| `generatedAt`    | timestamp |                                                       |

**Access**: admin only (same as `loans`).

> Note: `loan_receipts` is currently **website-only**; the Flutter app does not reference it. It's created purely by the website admin loan approval flow.

---

## `groups/{groupId}`

Super-admin-only collection for managing multiple fund groups via the website. Locked down to `admin001@lendwus.app` in `firestore.rules`.

| Field                | Type           | Notes                                    |
| -------------------- | -------------- | ------------------------------------------ |
| `groupCode`          | string         | Unique group code (e.g. `'LENDWUS'`)       |
| `name`               | string         | Display name                                |
| `adminEmails`        | array\<string> | Admin email list for this group             |
| `treasurerEmails`    | array\<string> | Treasurer email list                        |
| `loanInterestPercent`| double         | Default interest rate as whole %            |
| `currencySymbol`     | string         | `'₱'` \| `'$'` \| `'€'`                    |
| `currencyCode`       | string         | `'PHP'` \| `'USD'` \| `'EUR'`              |
| `isActive`           | bool           | Whether the group is active                 |
| `minPaymentPerHead`  | double         | Minimum per-head contribution               |
| `maxPaymentPerHead`  | double         | Maximum per-head contribution               |
| `createdAt`          | timestamp      |                                             |
| `updatedAt`          | timestamp?     |                                             |

**Access**: super admin only (`admin001@lendwus.app`).

> Note: The `groups` collection is **website-only** and separate from `app_settings/fund_settings`. The Flutter app reads `app_settings/fund_settings` for the single-group configuration; the website's Administrator page manages multiple group records in `groups`.

---

## `notifications/{notificationId}`

Per-user notifications (e.g. "your loan was approved", "contribution recorded").

| Field       | Type      | Notes                          |
| ----------- | --------- | --------------------------------- |
| `userId`    | string    | Recipient's auth UID               |
| `title`     | string    | Notification title                  |
| `body`      | string    | Notification body                   |
| `type`      | string    | e.g. `'payment_approved'`          |
| `data`      | map?      | Arbitrary payload data             |
| `read`      | bool      | Read/unread status                  |
| `createdAt` | timestamp |                                     |

**Access**:
- Create: any authenticated user
- Read / Update / Delete: the recipient (`userId == request.auth.uid`) or admin

---

## `activity_log/{logId}`

Audit trail of actions performed in the app.

| Field            | Type      | Notes                              |
| ---------------- | --------- | ------------------------------------ |
| `action`         | string    | e.g. `'create_loan'`                |
| `entityType`     | string    | `'loan'` \| `'member'` \| etc.      |
| `entityId`       | string?   | Document ID of the affected entity   |
| `performedBy`    | string?   | Auth UID of the actor               |
| `performedByName`| string?   | Display name of the actor           |
| `details`        | map?      | Arbitrary details about the action  |
| `createdAt`      | timestamp |                                     |

**Access**:
- Create: any authenticated user
- Read: admin only

---

## `user_settings/{userId}`

Per-user app preferences (notification toggles, display settings, etc.).

**Access**: read/write only by the owning user (`isOwner(userId)`).

---

## `otp_codes/{userId}`

One-time-password codes for email verification or 2FA flows.

**Access**: read/write only by the owning user (`isOwner(userId)`).

> Treat values here as sensitive/short-lived. Don't log or cache OTPs client-side.

---

## `email_logs/{logId}`

Record of emails sent (e.g. notifications, OTPs).

**Access**:
- Create: any authenticated user
- Read: admin only

---

## `backups/{backupId}`

Admin-only data backups/exports.

**Access**: admin only (read and write).

---

## `meta/{docId}`

General metadata documents. Admin-only read/write — **except**:

### `meta/member_counter`

Used to generate sequential member numbers/IDs.

| Field        | Type      | Notes                          |
| ------------ | --------- | --------------------------------- |
| `lastNumber` | int       | `1 <= lastNumber <= 999999`        |
| `updatedAt`  | timestamp |                                     |

**Access**:
- Read: any authenticated user
- Write: any authenticated user, **but** the rule restricts the write to only contain `lastNumber` and `updatedAt` keys, with `lastNumber` an int in `[1, 999999]`. This allows concurrent member self-onboarding to safely increment a shared counter without admin privileges.

---

## Access Model Summary

Two ways a user becomes admin (`isAdmin()` in `firestore.rules`):

1. `users/{uid}.role == 'admin'`
2. `request.auth.token.email` is in `app_settings/fund_settings.adminEmails`

Two ways a user is recognized as treasurer (`isTreasurer()` in `firestore.rules`):

1. `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isTreasurer == true`
2. `request.auth.token.email` is in `app_settings/fund_settings.treasurerEmails`

Two ways a user is considered "the member" for read access (`canReadMemberData`):

1. `users/{uid}.memberId == memberId` (linked at signup)
2. `members/{memberId}.linkedEmail == request.auth.token.email` (self-service linking by email)

If you change either admin-detection, treasurer-detection, or member-linking logic, update **both** the rule helper functions and any client-side role checks — see `CONTRIBUTING.md` → Security-Sensitive Changes.

---

## Indexes

Any compound query (e.g. `contributions` filtered by `memberId` + ordered by `date`, or `loans` filtered by `memberId` + `isFullyRepaid`) needs a matching entry in `firestore.indexes.json`, or it will fail at runtime with a missing-index error in production even if it works in the emulator/cache. Check this file before adding new filter+sort combinations to repository queries.

---

## Notes

- **Monetary values**: All monetary values stored as `double` (not centavos). See `sinking_fund_logic.md` §11 for the currency/locale configuration used for display formatting.
