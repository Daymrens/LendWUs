import React from "react";
import { useMemberAuth } from "../../context/MemberAuthContext";

const PrivacySecurity: React.FC = () => {
  const { user } = useMemberAuth();

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Privacy & Security</h1>
      </div>

      <div style={{ textAlign: "center", marginBottom: 32 }}>
        <div style={{ fontSize: 48, marginBottom: 12 }}>🔒</div>
        <h2 style={{ color: "#fff", marginBottom: 8 }}>Account Security</h2>
      </div>

      <div className="settings-section">
        <h2>Account Info</h2>
        <div className="form-group">
          <label>Email</label>
          <input type="email" value={user?.email || "N/A"} disabled />
        </div>
        <div className="form-group">
          <label>Member ID</label>
          <input type="text" value={user?.memberId || "Not linked"} disabled />
        </div>
      </div>

      <div className="settings-section">
        <h2>Data Management</h2>
        <button
          className="btn btn-outline btn-block"
          onClick={() => alert("Coming soon!")}
          style={{ marginBottom: 8 }}
        >
          📥 Export My Data
        </button>
        <button
          className="btn btn-outline btn-block"
          style={{ color: "#ef4444", borderColor: "#ef4444" }}
          onClick={() => {
            if (window.confirm("Are you sure you want to delete your account? This action cannot be undone.")) {
              alert("Account deletion is not yet implemented. Please contact support.");
            }
          }}
        >
          🗑️ Delete Account
        </button>
      </div>

      <div className="settings-section">
        <h2>Privacy</h2>
        <p style={{ color: "#8b949e", fontSize: 13, lineHeight: 1.6, margin: 0 }}>
          Your data is stored securely in Firebase Firestore with encrypted transmission.
          Only authorized group administrators can view member information.
          Your data is never shared with third parties.
        </p>
      </div>
    </div>
  );
};

export default PrivacySecurity;
