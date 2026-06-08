import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { doc, onSnapshot } from "firebase/firestore";
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

const Profile: React.FC = () => {
  const { user, logout } = useMemberAuth();
  const navigate = useNavigate();
  const [member, setMember] = useState<MemberData | null>(null);

  useEffect(() => {
    if (!user?.memberId) return;
    const unsub = onSnapshot(doc(db, "members", user.memberId), (snap) => {
      if (snap.exists()) setMember({ id: snap.id, ...snap.data() } as MemberData);
    });
    return unsub;
  }, [user?.memberId]);

  const handleLogout = async () => {
    await logout();
    window.location.href = "/member/login";
  };

  const initial = (user?.username || user?.email || "M")[0].toUpperCase();
  const joinedDate = member?.joinedAt?.toDate?.() || null;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>My Profile</h1>
      </div>

      <div className="settings-section" style={{ textAlign: "center", padding: "32px 24px" }}>
        <div style={{
          width: 80, height: 80, borderRadius: "50%", background: "#22c55e",
          display: "inline-flex", alignItems: "center", justifyContent: "center",
          fontSize: 36, fontWeight: 700, color: "#0d1117", marginBottom: 12,
        }}>
          {initial}
        </div>
        <h2 style={{ margin: "0 0 4px" }}>{user?.username || "Member"}</h2>
        <p style={{ color: "#8b949e", margin: 0, fontSize: 14 }}>
          {user?.customMemberId || "Member"} · {user?.email}
        </p>
      </div>

      <div className="mini-stats" style={{ marginBottom: 24 }}>
        <div className="mini-stat accent">
          <span className="mini-stat-label">Heads</span>
          <span className="mini-stat-value">{member?.headsCount ?? "-"}</span>
        </div>
        <div className="mini-stat">
          <span className="mini-stat-label">Per Head</span>
          <span className="mini-stat-value">₱{member?.amountPerHead?.toFixed(2) ?? "-"}</span>
        </div>
        <div className="mini-stat warning">
          <span className="mini-stat-label">Required</span>
          <span className="mini-stat-value">₱{member?.totalRequired?.toFixed(2) ?? "-"}</span>
        </div>
        <div className="mini-stat accent">
          <span className="mini-stat-label">Balance</span>
          <span className="mini-stat-value">₱{member?.balance?.toFixed(2) ?? "-"}</span>
        </div>
      </div>

      <div className="settings-section">
        <h2>Account Information</h2>
        <div className="form-group">
          <label>Name</label>
          <input type="text" value={user?.username || "N/A"} disabled />
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
        <h2>Quick Links</h2>
        <div className="member-card" onClick={() => navigate("/member/edit-profile")} style={{ cursor: "pointer", display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 16px", border: "1px solid #30363d", borderRadius: 8, marginBottom: 8 }}>
          <span>Edit Profile</span>
          <span style={{ color: "#8b949e" }}>→</span>
        </div>
        <div className="member-card" onClick={() => navigate("/member/privacy-security")} style={{ cursor: "pointer", display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 16px", border: "1px solid #30363d", borderRadius: 8, marginBottom: 8 }}>
          <span>Privacy & Security</span>
          <span style={{ color: "#8b949e" }}>→</span>
        </div>
        <div className="member-card" onClick={() => navigate("/member/notifications")} style={{ cursor: "pointer", display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 16px", border: "1px solid #30363d", borderRadius: 8, marginBottom: 8 }}>
          <span>Notifications</span>
          <span style={{ color: "#8b949e" }}>→</span>
        </div>
        <div className="member-card" onClick={() => navigate("/member/help-support")} style={{ cursor: "pointer", display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 16px", border: "1px solid #30363d", borderRadius: 8, marginBottom: 8 }}>
          <span>Help & Support</span>
          <span style={{ color: "#8b949e" }}>→</span>
        </div>
        <div className="member-card" onClick={() => navigate("/member/about")} style={{ cursor: "pointer", display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 16px", border: "1px solid #30363d", borderRadius: 8 }}>
          <span>About</span>
          <span style={{ color: "#8b949e" }}>→</span>
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
