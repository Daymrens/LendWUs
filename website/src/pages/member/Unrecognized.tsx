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
      <div className="app-login-page">
        <div className="app-login-card" style={{ textAlign: "center" }}>
          <div className="app-login-logo">
            <div className="app-login-logo-icon">💰</div>
            <h1 className="app-login-title">LendWUs</h1>
          </div>
          <div style={{ fontSize: 48, margin: "24px 0" }}>🤝</div>
          <h2 style={{ color: "#fff", margin: "0 0 8px" }}>Welcome to LendWUs!</h2>
          <p style={{ color: "#8b949e", marginBottom: 8 }}>You've joined as</p>
          <p style={{ fontSize: 18, fontWeight: 600, color: "#c9d1d9", marginBottom: 24 }}>{displayName}</p>
          <button
            className="app-login-submit"
            onClick={() => navigate("/member/dashboard")}
          >
            Let's Get Started
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="app-login-page">
      <div className="app-login-card">
        <div className="app-login-logo">
          <div className="app-login-logo-icon">
            💰
          </div>
          <h1 className="app-login-title">LendWUs</h1>
          <p className="app-login-subtitle">Join Group</p>
        </div>

        <div style={{ fontSize: 48, textAlign: "center", margin: "16px 0" }}>👤</div>
        <h2 style={{ color: "#fff", textAlign: "center", margin: "0 0 8px", fontSize: 20 }}>Member Not Recognized</h2>
        <p style={{ color: "#8b949e", textAlign: "center", marginBottom: 24, fontSize: 14 }}>
          Your account is not yet registered. Contact an admin or join using a group code.
        </p>

        {(localError || error) && <div className="form-error">{localError || error}</div>}

        <form onSubmit={e => { e.preventDefault(); handleJoin(); }}>
          <div className="app-login-input-group">
            <span className="app-login-input-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
            </span>
            <input
              type="text"
              value={code}
              onChange={e => setCode(e.target.value)}
              placeholder="Enter Group Code"
              style={{ textTransform: "uppercase" }}
              disabled={submitting}
              className="app-login-input"
              required
            />
          </div>

          <button type="submit" className="app-login-submit" disabled={submitting || !code.trim()}>
            {submitting ? "Joining..." : "Join Group"}
          </button>
        </form>

        <div className="app-login-divider">
          <span>OR</span>
        </div>

        <button className="app-login-google" onClick={handleLogout} disabled={submitting}>
          Log Out
        </button>

        <div className="app-login-footer">
          <a href="/member/login">Back to Sign In</a>
        </div>
      </div>
    </div>
  );
};

export default Unrecognized;
