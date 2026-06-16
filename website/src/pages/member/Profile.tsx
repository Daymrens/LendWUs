import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { doc, onSnapshot, updateDoc } from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";

interface MemberData {
  id: string;
  name: string;
  headsCount: number;
  amountPerHead: number;
  totalRequired: number;
  balance: number;
  memberId: string;
  linkedEmail?: string;
  joinedAt?: { toDate?: () => Date };
}

const formatCurrency = (n: number) =>
  n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const getInitials = (name: string): string => {
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  return (name[0] || "M").toUpperCase();
};

const Profile: React.FC = () => {
  const { user, logout } = useMemberAuth();
  const navigate = useNavigate();
  const [member, setMember] = useState<MemberData | null>(null);
  const [editing, setEditing] = useState(false);
  const [nameInput, setNameInput] = useState("");
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    if (!user?.memberId) return;
    const unsub = onSnapshot(doc(db, "members", user.memberId), (snap) => {
      if (snap.exists()) setMember({ id: snap.id, ...snap.data() } as MemberData);
    });
    return unsub;
  }, [user?.memberId]);

  useEffect(() => {
    if (user?.username) setNameInput(user.username);
  }, [user?.username]);

  const handleLogout = async () => {
    await logout();
    window.location.href = "/member/login";
  };

  const startEditing = () => {
    setNameInput(user?.username || "");
    setEditing(true);
    setMsg(null);
  };

  const cancelEditing = () => {
    setEditing(false);
    setMsg(null);
  };

  const saveName = async () => {
    if (!nameInput.trim()) return;
    setSaving(true);
    setMsg(null);
    try {
      if (user?.uid) {
        await updateDoc(doc(db, "users", user.uid), { username: nameInput.trim() });
        setMsg({ ok: true, text: "Name updated" });
        setEditing(false);
      }
    } catch (err: unknown) {
      setMsg({ ok: false, text: err instanceof Error ? err.message : "Failed to update" });
    } finally {
      setSaving(false);
    }
  };

  const displayName = user?.username || "Member";
  const initials = getInitials(displayName);
  const joinedDate = member?.joinedAt?.toDate?.() || null;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>My Profile</h1>
      </div>

      <div className="settings-section" style={{ textAlign: "center", padding: "32px 24px" }}>
        <div style={{
          width: 88, height: 88, borderRadius: "50%",
          background: "linear-gradient(135deg, #22c55e, #16a34a)",
          display: "inline-flex", alignItems: "center", justifyContent: "center",
          fontSize: 32, fontWeight: 700, color: "#0d1117", marginBottom: 12,
          boxShadow: "0 0 0 4px rgba(34,197,94,0.2)",
        }}>
          {initials}
        </div>
        <h2 style={{ margin: "0 0 4px", fontSize: 20 }}>{displayName}</h2>
        <p style={{ color: "#8b949e", margin: "0 0 4px", fontSize: 14 }}>
          {user?.email}
        </p>
        <div style={{
          display: "inline-block", marginTop: 8,
          background: "rgba(34,197,94,0.1)", color: "#22c55e",
          padding: "4px 14px", borderRadius: 20, fontSize: 13, fontWeight: 600,
          border: "1px solid rgba(34,197,94,0.2)",
        }}>
          {user?.customMemberId || "Member"}
        </div>
      </div>

      <div className="mini-stats" style={{ marginBottom: 24 }}>
        <div className="mini-stat accent">
          <span className="mini-stat-label">Heads</span>
          <span className="mini-stat-value">{member?.headsCount ?? "-"}</span>
        </div>
        <div className="mini-stat">
          <span className="mini-stat-label">Per Head</span>
          <span className="mini-stat-value">&#x20B1;{member?.amountPerHead != null ? formatCurrency(member.amountPerHead) : "-"}</span>
        </div>
        <div className="mini-stat warning">
          <span className="mini-stat-label">Required</span>
          <span className="mini-stat-value">&#x20B1;{member?.totalRequired != null ? formatCurrency(member.totalRequired) : "-"}</span>
        </div>
        <div className="mini-stat accent">
          <span className="mini-stat-label">Balance</span>
          <span className="mini-stat-value">&#x20B1;{member?.balance != null ? formatCurrency(member.balance) : "-"}</span>
        </div>
      </div>

      <div className="settings-section">
        <div className="settings-section-header">
          <div className="settings-section-icon">&#x1F464;</div>
          <h2>Account Information</h2>
          {!editing && (
            <button className="btn btn-outline btn-sm" onClick={startEditing} style={{ marginLeft: "auto" }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
              Edit
            </button>
          )}
        </div>

        {msg && (
          <div className={`send-notif-result ${msg.ok ? "success" : "error"}`} style={{ marginBottom: 12 }}>
            {msg.ok ? "\u2705" : "\u26A0\uFE0F"} {msg.text}
          </div>
        )}

        <div className="form-group">
          <label>Name</label>
          {editing ? (
            <div style={{ display: "flex", gap: 8 }}>
              <input type="text" value={nameInput} onChange={e => setNameInput(e.target.value)} autoFocus style={{ flex: 1 }} />
              <button className="btn btn-primary btn-sm" onClick={saveName} disabled={saving || !nameInput.trim()}>
                {saving ? "Saving..." : "Save"}
              </button>
              <button className="btn btn-outline btn-sm" onClick={cancelEditing}>Cancel</button>
            </div>
          ) : (
            <input type="text" value={displayName} disabled />
          )}
        </div>
        <div className="form-group">
          <label>Email</label>
          <input type="email" value={user?.email || "N/A"} disabled />
        </div>
        <div className="form-group">
          <label>Member ID</label>
          <input type="text" value={user?.customMemberId || "N/A"} disabled />
        </div>
        <div className="form-group">
          <label>Member Since</label>
          <input type="text" value={joinedDate ? joinedDate.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" }) : "N/A"} disabled />
        </div>
      </div>

      <div className="settings-section">
        <div className="settings-section-header">
          <div className="settings-section-icon">&#x1F517;</div>
          <h2>Quick Links</h2>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {[
            { label: "Privacy & Security", icon: "\uD83D\uDD12", path: "/member/privacy-security" },
            { label: "Help & Support", icon: "\u2753", path: "/member/help-support" },
            { label: "About", icon: "\u2139\uFE0F", path: "/member/about" },
            { label: "What's New", icon: "\u{1F195}", path: "/member/changelog" },
          ].map(link => (
            <div
              key={link.path}
              className="member-card"
              onClick={() => navigate(link.path)}
              style={{ cursor: "pointer", gap: 12, transition: "border-color 0.15s, box-shadow 0.15s" }}
              onMouseEnter={e => { e.currentTarget.style.borderColor = "#22c55e44"; e.currentTarget.style.boxShadow = "0 0 0 1px rgba(34,197,94,0.15)"; }}
              onMouseLeave={e => { e.currentTarget.style.borderColor = "#21262d"; e.currentTarget.style.boxShadow = "none"; }}
            >
              <div style={{
                width: 32, height: 32, borderRadius: 8,
                background: "rgba(139,148,158,0.08)",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 16, flexShrink: 0,
              }}>
                {link.icon}
              </div>
              <span style={{ flex: 1, color: "#e6edf3", fontWeight: 500, fontSize: 14 }}>{link.label}</span>
              <span style={{ color: "#8b949e", fontSize: 14 }}>&rarr;</span>
            </div>
          ))}
        </div>
      </div>

      <div className="settings-section">
        <button className="btn btn-outline" style={{ color: "#ef4444", borderColor: "#ef4444", width: "100%" }} onClick={handleLogout}>
          Sign Out
        </button>
      </div>
    </div>
  );
};

export default Profile;
