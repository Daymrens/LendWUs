import React from "react";

interface ChangelogEntry {
  version: string;
  date: string;
  additions: string[];
  fixes: string[];
  changes: string[];
}

const changelog: ChangelogEntry[] = [
  {
    version: "1.2.0",
    date: "June 2026",
    additions: [
      "Biometric fingerprint login with app-reopen verification",
      "Notification clear/delete for members (swipe-to-delete, clear read, clear all)",
      "Member notification UI enhancement with type-colored icons and filters",
      "Changelog screen with version history",
    ],
    fixes: [
      "Firestore rules missing for user_settings/otp_codes/email_logs/backups (permission denied on biometric enable)",
      "Biometric enrollment not persisting credentials for login screen",
      "Post-login biometric prompt Enable button not triggering fingerprint scan",
    ],
    changes: [
      "Enhanced notifications screen with filter bar (All/Unread) and unread badge",
      "Improved security: credentials stored via flutter_secure_storage",
    ],
  },
  {
    version: "1.1.0",
    date: "May 2026",
    additions: [
      "Admin: bulk loan processing via CSV paste",
      "Admin: compliance reports with real data aggregation",
      "Admin: member migration with transaction support",
      "Admin: send notification screen with templates",
      "Maintenance mode for app-wide lockdown",
      "Web: member performance analytics dashboard",
      "Web: activity feed with real-time updates",
    ],
    fixes: [
      "Interest rate format inconsistency across codebases",
      "Amortization formula using multiplication instead of exponentiation",
      "ActivityLog crash on Firestore Timestamp parsing",
      "Biometric stub returning true without device check",
      "Hardcoded admin emails removed; relies on Firestore settings",
    ],
    changes: [
      "Consolidated profile and edit-profile screens",
      "Route-level auth guards (admin routes blocked for members, vice versa)",
      "Added composite indexes for key queries",
    ],
  },
  {
    version: "1.0.0",
    date: "April 2026",
    additions: [
      "Initial release of LendWUs Group Sinking Fund Manager",
      "Member management with head count and contribution tracking",
      "Loan issuance, repayment, and amortization schedule",
      "Admin dashboard with fund summary and quick actions",
      "Member dashboard with balance, contribution, and loan status",
      "Firebase Auth with email/password and Google Sign-In",
      "Real-time Firestore sync with Riverpod state management",
      "Approval workflow for payments, loans, and head changes",
      "Push notifications via Firebase Cloud Messaging",
      "Web counterpart with React 18 + TypeScript",
    ],
    fixes: [],
    changes: [],
  },
];

const Changelog: React.FC = () => {
  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>What's New</h1>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
        {changelog.map((entry, i) => {
          const isLatest = i === 0;
          return (
            <div
              key={entry.version}
              className="member-card"
              style={{
                border: isLatest ? "1px solid rgba(34,197,94,0.4)" : "1px solid rgba(139,148,158,0.15)",
                padding: 20,
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
                <span
                  style={{
                    display: "inline-flex",
                    padding: "4px 12px",
                    borderRadius: 8,
                    background: isLatest ? "#22c55e" : "#1c2333",
                    color: isLatest ? "#fff" : "#f0f6fc",
                    fontWeight: 700,
                    fontSize: 14,
                  }}
                >
                  v{entry.version}
                </span>
                <span style={{ color: "rgba(139,148,158,0.7)", fontSize: 13 }}>{entry.date}</span>
                {isLatest && (
                  <span
                    style={{
                      padding: "2px 8px",
                      borderRadius: 12,
                      background: "rgba(34,197,94,0.15)",
                      color: "#22c55e",
                      fontSize: 11,
                      fontWeight: 600,
                    }}
                  >
                    Latest
                  </span>
                )}
              </div>

              {entry.additions.length > 0 && (
                <>
                  <SectionHeader label="Added" color="#22c55e" />
                  <div style={{ marginBottom: 12 }}>
                    {entry.additions.map((item, j) => (
                      <BulletItem key={j} text={item} color="#22c55e" />
                    ))}
                  </div>
                </>
              )}

              {entry.fixes.length > 0 && (
                <>
                  <SectionHeader label="Fixed" color="#f97316" />
                  <div style={{ marginBottom: 12 }}>
                    {entry.fixes.map((item, j) => (
                      <BulletItem key={j} text={item} color="#f97316" />
                    ))}
                  </div>
                </>
              )}

              {entry.changes.length > 0 && (
                <>
                  <SectionHeader label="Changed" color="#3b82f6" />
                  <div style={{ marginBottom: 0 }}>
                    {entry.changes.map((item, j) => (
                      <BulletItem key={j} text={item} color="#3b82f6" />
                    ))}
                  </div>
                </>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

function SectionHeader({ label, color }: { label: string; color: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
      <div style={{ width: 3, height: 14, borderRadius: 2, background: color }} />
      <span style={{ color, fontWeight: 700, fontSize: 13 }}>{label}</span>
    </div>
  );
}

function BulletItem({ text, color }: { text: string; color: string }) {
  return (
    <div style={{ display: "flex", gap: 10, paddingLeft: 11, marginBottom: 4 }}>
      <div style={{ marginTop: 7, width: 5, height: 5, borderRadius: "50%", background: color, flexShrink: 0 }} />
      <span style={{ color: "#8b949e", fontSize: 13, lineHeight: 1.4 }}>{text}</span>
    </div>
  );
}

export default Changelog;
