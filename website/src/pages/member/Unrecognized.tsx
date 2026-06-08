import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

const Unrecognized: React.FC = () => {
  const [code, setCode] = useState("");
  const [localError, setLocalError] = useState("");
  const [welcome, setWelcome] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [displayName, setDisplayName] = useState("");
  const { joinWithGroupCode, error, clearError, firebaseUser, logout } = useAuth();
  const navigate = useNavigate();

  const handleJoin = async () => {
    setLocalError("");
    clearError();
    setSubmitting(true);
    try {
      const result = await joinWithGroupCode(code);
      if (result.success) {
        setWelcome(true);
        setDisplayName(firebaseUser?.displayName || firebaseUser?.email?.split("@")[0] || "Member");
      } else {
        setLocalError(result.error || "Invalid group code");
      }
    } catch {
      setLocalError("An unexpected error occurred");
    } finally {
      setSubmitting(false);
    }
  };

  const handleLogout = async () => {
    await logout();
    navigate("/member/login");
  };

  if (welcome) {
    return (
      <div className="login-page">
        <div className="login-card" style={{ textAlign: "center" }}>
          <div className="login-logo">
            <span className="logo-text">Lend<span className="logo-accent">WUs</span></span>
          </div>
          <div style={{ fontSize: 48, margin: "24px 0" }}>🤝</div>
          <h2>Welcome to LendWUs!</h2>
          <p style={{ color: "#8b949e", marginBottom: 8 }}>You've joined as</p>
          <p style={{ fontSize: 18, fontWeight: 600, color: "#c9d1d9", marginBottom: 24 }}>{displayName}</p>
          <button
            className="btn btn-primary btn-block"
            onClick={() => navigate("/member/dashboard")}
          >
            Let's Get Started
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-logo">
          <span className="logo-text">Lend<span className="logo-accent">WUs</span></span>
          <span className="logo-sub">Join Group</span>
        </div>
        <div style={{ fontSize: 48, textAlign: "center", margin: "16px 0" }}>👤</div>
        <h2 style={{ textAlign: "center" }}>Member Not Recognized</h2>
        <p style={{ color: "#8b949e", textAlign: "center", marginBottom: 24, fontSize: 14 }}>
          Your account is not yet registered. You can contact an admin or join using a group code if you have one.
        </p>
        {(localError || error) && <div className="form-error">{localError || error}</div>}
        <div className="form-group">
          <label htmlFor="groupCode">Enter Group Code</label>
          <input
            id="groupCode"
            type="text"
            value={code}
            onChange={e => setCode(e.target.value)}
            placeholder="e.g. LENDWUS"
            style={{ textTransform: "uppercase" }}
            disabled={submitting}
          />
        </div>
        <button className="btn btn-primary btn-block" onClick={handleJoin} disabled={submitting || !code.trim()}>
          {submitting ? "Joining..." : "Join Group"}
        </button>
        <div style={{ marginTop: 16, textAlign: "center" }}>
          <button className="btn btn-outline btn-block" onClick={handleLogout} disabled={submitting}>
            Log Out
          </button>
        </div>
        <a href="/member/login" className="back-link">← Back to Sign In</a>
      </div>
    </div>
  );
};

export default Unrecognized;
