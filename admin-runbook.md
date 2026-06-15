# Admin Runbook — LendWUs

Practical "how do I..." guide for the fund admin(s). For schema details referenced below, see `docs/firestore-schema.md`. For formulas, see `sinking_fund_logic.md`.

Admins are determined by either `users/{uid}.role == 'admin'` or being listed in `app_settings/fund_settings.adminEmails` (currently `act.drapor@gmail.com`, `daymrens@gmail.com`).

Treasurers are members with the `isTreasurer` flag, determined by either `users/{uid}.isTreasurer == true` or being listed in `app_settings/fund_settings.treasurerEmails`. Treasurers can view all payment requests and mark bank receipts as confirmed before admin approval.

---

## Adding a New Member

1. New member downloads the app and signs up (email/password or Google).
2. They enter the group code **`LENDWUS`** during self-onboarding — this creates a `members/{memberId}` document and a `users/{uid}` doc with `memberId` set.
3. As admin, go to **Member Management** and verify:
   - `name` is correct
   - `headsCount` matches what was agreed (≥ 1)
   - `amountPerHead` matches the current per-head contribution rate (in centavos — e.g. ₱150.00 = `15000`)
   - `active = true`
4. If the member signed up with a different email than expected, set `linkedEmail` on their `members` doc to match their auth email so `isMemberByLinkedEmail()` can resolve access correctly.

---

## Recording a Contribution

**Direct entry (admin-recorded):**
1. Go to the member's profile → Add Contribution.
2. Enter `amount` (centavos), attach receipt if provided.
3. Save — this writes directly to `contributions/{contributionId}` with `memberId`, `amount`, `date` (server timestamp), `receiptUrl`.

**Via member self-submission (payment request) — with treasurer:**
1. Member submits via their app — creates `payment_requests/{requestId}` with `status: 'pending'`, `receiptUrl`.
2. **Treasurer** reviews under their dashboard. If the bank deposit receipt looks valid, they tap **"Confirm Bank Received"** — this sets `bankConfirmed = true`, `bankConfirmedAt`, `bankConfirmedBy` on the request doc. A notification is sent to all admins.
3. **Admin** reviews under **Approvals**. On approve:
   - Set `payment_requests/{requestId}.status = 'approved'`
   - Create a matching `contributions/{contributionId}` doc with the same `memberId`/`amount`/`receiptUrl`
   - Both writes should happen together (batch) — if you're doing this manually via console, do the contribution write first, then mark the request approved, so a partial failure doesn't leave an "approved" request with no recorded contribution.
4. On reject: set `status: 'rejected'`. No contribution doc is created.

**Via member self-submission (payment request) — no treasurer configured:**
1. Member submits via their app — creates `payment_requests/{requestId}` with `status: 'pending'`, `receiptUrl`.
2. Admin reviews under **Approvals**. On approve:
   - Set `payment_requests/{requestId}.status = 'approved'`
   - Create a matching `contributions/{contributionId}` doc with the same `memberId`/`amount`/receipt
   - Both writes should happen together (batch) — if you're doing this manually via console, do the contribution write first, then mark the request approved, so a partial failure doesn't leave an "approved" request with no recorded contribution.
3. On reject: set `status: 'rejected'`. No contribution doc is created.

---

## Fixing a Wrong Contribution Entry

There's **no edit history / audit log** beyond `email_logs`, so be careful:

1. Locate the incorrect `contributions/{contributionId}` doc (filter by `memberId` + date in the admin reports view, or directly in Firebase Console).
2. **Wrong amount**: update the `amount` field directly. This will retroactively affect:
   - That member's monthly `paymentStatus` / progress %
   - `fundBalance` (since `totalContributions` feeds into it)
   - Any `MonthlyReport` for that month (recomputed on read, so no stale cache to worry about)
3. **Wrong member**: don't just change `memberId` — delete the doc and recreate it under the correct member, so any per-member aggregates relying on document identity stay consistent.
4. **Duplicate entry**: delete the extra `contributions` doc (admin-only delete per rules).

After any correction, spot-check the Dashboard totals and the affected member's monthly status to confirm the numbers now look right.

---

## Issuing a Loan

1. Check **Available to Loan** on the dashboard:
   ```
   availableToLoan = fundBalance - sum(remainingBalance of all not-fully-repaid loans)
   ```
   The requested principal must not exceed this.
2. Confirm the borrower:
   - Is an active member
   - Has **no existing unpaid loan** (one active loan per member at a time)
3. Set `interestRate` (simple interest, e.g. `0.05` for 5%) and `dueDate` (must be in the future — typically +30 or +60 days per fund policy).
4. Create the `loans/{loanId}` doc with `principal`, `interestRate`, `issuedDate` = now, `dueDate`, `isFullyRepaid = false`.
5. If this came from an approved `loan_requests/{requestId}`, mark that request `status: 'approved'` after the loan doc is created.

**If you reject instead**: set `loan_requests/{requestId}.status = 'rejected'`. No loan doc is created.

---

## Recording a Loan Repayment

1. Open the loan under the member's profile.
2. Check current `remainingBalance = totalAmountDue - totalRepaid`.
3. Enter `amountPaid`:
   - If `amountPaid <= remainingBalance`: normal repayment.
   - If `amountPaid > remainingBalance`: this is an **overpayment** — the app should warn you. Decide with the member whether the excess becomes an advance contribution or is returned; record accordingly (don't silently absorb it into the loan).
4. Create `repayments/{repaymentId}` with `loanId`, `amountPaid`, `date`.
5. After saving, the loan's `remainingBalance` recomputes. If it's now `<= 0`, set `loans/{loanId}.isFullyRepaid = true`.
6. The portion of cumulative repayments exceeding `principal` is recognized as **interest earned** — this flows into `totalInterestEarned`, which feeds the end-of-year returns calculation. No separate entry needed; it's derived.

---

## Handling an Overdue Loan

A loan is overdue if `dueDate` has passed and `isFullyRepaid == false`.

1. The app should flag this with a warning badge on the member's tile (dashboard).
2. Follow up with the member directly — there's no automated reminder system (no Cloud Functions for scheduled notifications).
3. Options:
   - Accept partial repayment (loan stays open, `remainingBalance` updates)
   - Extend `dueDate` if the family agrees — update the loan doc
   - In extreme cases, write off the loss — this isn't modeled in the current schema; document it manually outside the app (e.g. in fund meeting notes) since writing it off would distort `totalInterestEarned`/`fundBalance` if done carelessly.

---

## Changing a Member's Head Count

1. Member submits a request via the app → `head_change_requests/{requestId}` with `status: 'pending'`, `requestedHeads`.
2. Admin reviews. On approve:
   - Update `members/{memberId}.headsCount = requestedHeads`
   - Set `head_change_requests/{requestId}.status = 'approved'`
3. **Effective timing**: decide whether the new head count applies starting next month or retroactively. The schema doesn't track "effective date" for head changes — if mid-month changes matter for your family's rules, note the change date manually (e.g. in the request doc or a side note) until this is modeled properly.

---

## Removing a Member

1. Check the member has **no outstanding (not fully repaid) loan** — the app should block deletion otherwise ("Cannot remove member with outstanding loan", per `sinking_fund_logic.md` §11).
2. If they have an unpaid loan, resolve it first (full repayment or documented write-off per the overdue-loan process above).
3. Once clear, delete `members/{memberId}` (admin-only). Their historical `contributions`, `loans`, and `repayments` docs remain for record-keeping — they're not cascade-deleted.
4. Consider also removing/deactivating their `users/{uid}` doc if they're leaving the family circle entirely, and revoke `linkedEmail` if reused for someone else.

---

## End-of-Year Returns Computation

Run once per year (manually triggered — no scheduled Functions):

1. Compute `totalInterestEarned` = sum across all loans of `max(0, totalRepaid - principal)`.
2. Compute `totalHeads` = sum of `headsCount` across all **active** members at computation time.
3. **Guard**: if `totalHeads == 0`, do not compute — there's nothing to distribute (avoid division by zero).
4. `perHeadShare = totalInterestEarned / totalHeads` (centavos; expect rounding — decide and document how remainders are handled, e.g. largest-remainder method or rounding down with leftover staying in the fund).
5. For each member: `share = headsCount * perHeadShare`.
6. Write a `returns/{docId}` doc with `year`, `totalInterestEarned`, `totalHeads`, `perHeadShare`, and `memberShares` map.
7. This doc is admin-write-only but readable by all members — they'll see their share reflected in their dashboard.

---

## Changing Currency or Interest Rate Defaults

1. Go to **Admin Settings** → update `app_settings/fund_settings.currency` (`PHP`/`USD`/`EUR`) or `loanInterestRate`.
2. **Currency change affects display only** going forward — existing `contributions`/`loans`/`repayments` amounts are stored as raw centavo integers and won't be retroactively converted. Changing currency mid-fund-cycle will make historical and new amounts inconsistent in real-world value; avoid doing this except at the start of a new cycle, and communicate clearly to members if it happens.
3. `loanInterestRate` changes only affect **new** loans — existing loans keep the `interestRate` stored on their own document.

---

## Managing Admins

- Adding an admin: either set `users/{uid}.role = 'admin'` for their account, **or** add their email to `app_settings/fund_settings.adminEmails`.
- Removing an admin: remove from `adminEmails` **and** check/clear `users/{uid}.role` if it was set to `'admin'` — both paths grant access, so both must be revoked.
- Be cautious editing `adminEmails` directly in Firestore — a typo could lock out the only admin account. Test with a second admin account before removing the last one from a list.

---

## Managing Treasurers

- **Adding a treasurer**: add their email to `app_settings/fund_settings.treasurerEmails`. On next sign-in, the auth flow detects the email in the list and sets `users/{uid}.isTreasurer = true`.
- **Removing a treasurer**: remove their email from `treasurerEmails`. Also manually set `users/{uid}.isTreasurer = false` if you want to immediately revoke access — the list-only check in the `isTreasurer` getter will already return `false`, but the doc flag may still show `true`.
- **Treasurer vs admin**: treasurers can only view payment requests and mark `bankConfirmed` — they cannot approve/reject requests, manage members, issue loans, or access any admin screens. If a treasurer email is also in `adminEmails`, the user gets both roles (admin takes precedence for routing).
- **Notification on role change**: existing users get upgraded on their next sign-in via `checkTreasurerEmail()` (web) or `_treasurerEmails` check (Flutter). If the upgrade doesn't appear, have them sign out and sign back in.

---

## Things With No Built-In Tooling (Manual Workarounds)

Since there are no Cloud Functions, these have no automation — track manually if needed:

- Scheduled reminders (overdue loans, monthly contribution due dates)
- Audit trail / edit history for corrected entries (beyond `email_logs`, which only logs emails sent)
- Automated backups (`backups/{backupId}` collection exists but nothing writes to it automatically — manual export via Firebase Console if needed)
- Loan write-offs / bad debt handling
