# LendWUs Project Structure

## Overview
LendWUs is a group sinking fund management app with two codebases in one repo:

| Platform | Location | Tech Stack |
|----------|----------|------------|
| **Mobile App** | `/` (root) | Flutter + Dart, Firebase Auth, Firestore, Firebase Messaging |
| **Web App** | `/website/` | React 18 + TypeScript, Firebase JS SDK v12, Recharts, react-router-dom v7 |

Both share the same Firebase project (`lmsystemm`, region `asia-east2`).

---

## Mobile App (`/` - Flutter)

### Key Directories
```
lib/
  app.dart                  - GoRouter routes (~456 lines), theme + nav bars
  core/
    firebase/
      firebase_service.dart - FirebaseService (static auth/firestore access, seedDefaults, uploadReceiptImage)
    services/               - 7 services: security, notification_watcher, reminder_service,
                              notification_service, email_notification_service, csv_export_service, storage_service
    utils/                  - 7 utils: interest_calculator, firestore_helpers, export_utils,
                              currency_formatter, cutoff_calculator, date_formatter, member_id_generator
  data/
    models/                 - 15 models: Member, Loan, Contribution, Repayment, ReturnsInfo, MonthlyReport,
                              AppSettings, FundSummary, User, LoanRequest, PaymentRequest,
                              MemberWithStatus, NotificationItem, ActivityLog, HeadChangeRequest
    repositories/           - 12 repos: member, loan, contribution, activity_log, settings, returns,
                              user, loan_request, fund, head_change_request, notification, payment_request
  providers/                - 13 Riverpod providers (members_provider, loans_provider, auth_provider,
                              fund_provider, reports_provider, settings_provider, theme_provider, etc.)
  screens/
    admin/                  - analytics_dashboard, export_screen, member_migration, bulk_loan_processing,
                              compliance_reports, member_performance_analytics, admin_settings_screen,
                              activity_feed_screen, admin_data_screen, approvals_screen,
                              member_balance_screen, member_profile_screen
    auth/                   - login_screen, welcome_screen (no "register" — it's welcome_screen)
    contributions/          - contributions_screen
    dashboard/              - dashboard_screen (admin)
    loans/                  - loans_screen
    member/                 - member_dashboard, member_contributions, member_loans, member_requests,
                              loan_calculator, amortization_screen, member_pay_screen,
                              member_loan_request_screen
    members/                - members_screen
    modals/                 - 8 modals: record_repayment, member_payment, issue_loan, member_head_change,
                              new_contribution, add_member, member_loan_request, pending_approval_dialog
    notifications/          - notifications_screen
    onboarding/             - introduction_screen
    profile/                - profile_screen, help_support_screen, about_screen,
                              privacy_security_screen, edit_profile_screen
    reports/                - reports_screen
  widgets/                  - wave_nav_bar
```

### Routes (`app.dart`)
Routes are split into 3 groups: public (no shell), admin shell, member shell.

**Public (no shell):**
| Route | Screen |
|-------|--------|
| `/login` | LoginScreen |
| `/intro` | IntroductionScreen |
| `/unrecognized` | UnrecognizedScreen |
| `/help` | HelpSupportScreen |
| `/about` | AboutScreen |
| `/privacy-security` | PrivacySecurityScreen |
| `/edit-profile` | EditProfileScreen |
| `/notifications` | NotificationsScreen |

**Admin ShellRoute (BottomNavigationBar: Home, Members, Contribs, Loans, Reports, Profile, Activity):**
| Route | Screen |
|-------|--------|
| `/` | DashboardScreen |
| `/members` | MembersScreen |
| `/contributions` | ContributionsScreen |
| `/loans` | LoansScreen |
| `/reports` | ReportsScreen |
| `/approvals` | ApprovalsScreen |
| `/settings` | AdminSettingsScreen |
| `/data-management` | AdminDataScreen |
| `/member-balances` | MemberBalanceScreen |
| `/member-profile/:memberId` | AdminMemberProfileScreen |
| `/profile` | ProfileScreen |
| `/export` | ExportScreen |
| `/activity` | ActivityFeedScreen |
| `/analytics` | AnalyticsDashboard |
| `/member-performance` | MemberPerformanceAnalytics |
| `/member-migration` | MemberMigrationScreen |
| `/bulk-loans` | BulkLoanProcessingScreen |
| `/compliance-reports` | ComplianceReportsScreen |

**Member ShellRoute (BottomNavigationBar: Home, My Contribs, Loans, Requests, Profile):**
| Route | Screen |
|-------|--------|
| `/member-home` | MemberDashboardScreen |
| `/member-contributions` | MemberContributionsScreen |
| `/member-loans` | MemberLoansScreen |
| `/member-requests` | MemberRequestsScreen |
| `/member-profile` | ProfileScreen |
| `/loan-calculator` | LoanCalculatorScreen |

### Key Models
- **Member**: id?, memberId?, name, headsCount, amountPerHead, totalRequired, balance, avatarPath?, joinedAt, isActive, linkedEmail?
- **Loan**: id?, memberId, principal, interestRate, issuedDate, dueDate, isFullyRepaid
- **Contribution**: id?, memberId, amount, date, month, year, notes?, createdBy?
- **Repayment**: id?, loanId, amountPaid, date
- **ReturnsInfo**: totalReturns, totalHeads, perHeadShare (computed)
- **MonthlyReport**: month, year, totalContribution, loansIssued, interestGained, endingBalance
- Other models: AppSettings, FundSummary, User, LoanRequest, PaymentRequest, MemberWithStatus, NotificationItem, ActivityLog, HeadChangeRequest

### Commands
```bash
flutter pub get
flutter analyze
flutter test
flutter run          # mobile
flutter run -d chrome # web (if web support enabled)
```

---

## Web App (`/website/` - React)

### Key Directories
```
website/src/
  pages/
    admin/          - 17 files: Dashboard, Members, MemberProfile, Approvals, Activity, Reports,
                      DataManagement, Settings, Notifications, GlobalSearch, ExportPage,
                      AnalyticsDashboard, MemberPerformance, MemberMigration, BulkLoanProcessing,
                      ComplianceReports, Login (unused)
    member/         - 14 files + modals/: Dashboard, Loans, Contributions, Requests, Profile,
                      Notifications, EditProfile, HelpSupport, About, PrivacySecurity,
                      Unrecognized, LoanCalculator, Login (unused)
    Login.tsx       - The actual login component used by App.tsx
  context/
    AuthContext.tsx  - Auth provider (login, Google sign-in, join with group code, resolveUser)
    MemberAuthContext.tsx - Thin re-export wrapper (unused directly)
  utils/
    export.ts       - downloadCSV helper
    memberId.ts     - Member ID generation (LWS-######)
  firebase.ts       - Firebase config (project: lmsystemm, region: asia-east2)
  App.tsx           - All routes, AdminLayout, MemberLayout, LandingPage (578 lines)
  App.css           - Dark theme, responsive layout, modals, tables (~2050 lines)
```

### Routes (`App.tsx`)
All admin routes are wrapped in `<ProtectedRoute>` + `<AdminLayout>`; member routes in `<ProtectedMemberRoute>` + `<MemberLayout>`.

| Route | Component | Auth |
|-------|-----------|------|
| `/` | LandingPage | Public |
| `/login` | Login | Public |
| `/admin` | Redirect → `/login` | — |
| `/ios` | Redirect → `/login` | — |
| `/member/login` | Redirect → `/login` | — |
| `*` (catch-all) | Redirect → `/` | — |
| `/admin/dashboard` | Dashboard | Admin |
| `/admin/members` | Members | Admin |
| `/admin/members/:id` | MemberProfile | Admin |
| `/admin/approvals` | Approvals | Admin |
| `/admin/activity` | Activity | Admin |
| `/admin/settings` | Settings | Admin |
| `/admin/reports` | Reports | Admin |
| `/admin/data` | DataManagement | Admin |
| `/admin/notifications` | Notifications | Admin |
| `/admin/export` | ExportPage | Admin |
| `/admin/analytics` | AnalyticsDashboard | Admin |
| `/admin/member-performance` | MemberPerformance | Admin |
| `/admin/member-migration` | MemberMigration | Admin |
| `/admin/bulk-loans` | BulkLoanProcessing | Admin |
| `/admin/compliance-reports` | ComplianceReports | Admin |
| `/member/unrecognized` | MemberUnrecognized | Public |
| `/member/dashboard` | MemberDashboard | Member |
| `/member/loans` | MemberLoans | Member |
| `/member/contributions` | MemberContributions | Member |
| `/member/requests` | MemberRequests | Member |
| `/member/profile` | MemberProfilePage | Member |
| `/member/notifications` | MemberNotifications | Member |
| `/member/edit-profile` | MemberEditProfile | Member |
| `/member/help-support` | MemberHelpSupport | Member |
| `/member/about` | MemberAbout | Member |
| `/member/privacy-security` | MemberPrivacySecurity | Member |
| `/member/loan-calculator` | LoanCalculator | Member |

### Layouts
- **AdminLayout** sidebar nav: Dashboard, Members, Approvals, Activity, Reports, Notifications, Export, Analytics, Performance, Migration, Bulk Loans, Compliance, Data Mgmt, Settings + search toggle + sign out
- **MemberLayout** sidebar nav: Home, Loans, Contributions, Requests, Loan Calc, Notifications, Profile, Edit Profile, Privacy & Security, Help & Support, About + sign out

### Authentication Flow
1. User signs in via email/password or Google
2. `resolveUser()` checks Firestore `users/{uid}` doc
3. If no user doc: checks if email is in `app_settings/fund_settings.adminEmails[]` (creates admin doc), or searches `members` collection for `linkedEmail` match (creates member doc)
4. If user exists: validates role, resolves member linkage (with repair fallback via `linkedEmail`)
5. Member accounts watch their member doc via `onSnapshot` for deactivation detection
6. `joinWithGroupCode("LENDWUS")` creates a member doc + `users/{uid}` doc in a Firestore transaction for signed-in Firebase users without an existing member record

### Commands
```bash
cd website
npm install    # install dependencies
npm start      # dev server on localhost:3000
npm run build  # production build
```
