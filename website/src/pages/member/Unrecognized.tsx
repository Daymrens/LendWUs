import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { doc, getDoc, collection, query, where, getDocs } from "firebase/firestore";
import { db } from "../../firebase";

const Unrecognized: React.FC = () => {
  const [name, setName] = useState("");
  const [heads, setHeads] = useState("1");
  const [contact, setContact] = useState("");
  const [code, setCode] = useState("");
  const [localError, setLocalError] = useState("");
  const [welcome, setWelcome] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [displayName, setDisplayName] = useState("");
  const [existingUserMode, setExistingUserMode] = useState(false);
  const [showPrompt, setShowPrompt] = useState(true);
  const [dataLoaded, setDataLoaded] = useState(false);
  const { joinWithGroupCode, completeProfile, error, clearError, user, isRecognized, needsSetup, logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    const loadMember = async (memberId: string) => {
      try {
        const memberSnap = await getDoc(doc(db, "members", memberId));
        if (memberSnap.exists()) {
          const mData = memberSnap.data();
          setName(mData.name || "");
          setHeads(String(mData.headsCount || 1));
          if (mData.contactNumber) setContact(mData.contactNumber);
          setCode((mData.memberId || "").startsWith("LWS") ? "Already joined" : "");
          setExistingUserMode(true);
          setShowPrompt(false);
        }
      } catch (_) { /* ignore */ }
      setDataLoaded(true);
    };

    if (isRecognized && needsSetup && user?.memberId) {
      loadMember(user.memberId);
      return;
    }

    // Also try by linked email if we have a user but no memberId yet
    if (user?.email && !user?.memberId) {
      (async () => {
        try {
          const membersSnap = await getDocs(
            query(collection(db, "members"), where("linkedEmail", "==", user!.email))
          );
          if (!membersSnap.empty) {
            const mData = membersSnap.docs[0].data();
            const docId = membersSnap.docs[0].id;
            setName(mData.name || "");
            setHeads(String(mData.headsCount || 1));
            if (mData.contactNumber) setContact(mData.contactNumber);
            setCode((mData.memberId || "").startsWith("LWS") ? "Already joined" : "");
            setExistingUserMode(true);
            setShowPrompt(false);
          }
        } catch (_) { /* ignore */ }
        setDataLoaded(true);
      })();
    } else {
      setDataLoaded(true);
    }
  }, [isRecognized, needsSetup, user?.memberId, user?.email]);

  const handleJoin = async () => {
    const trimmedName = name.trim();
    if (!trimmedName) {
      setLocalError("Display name is required");
      return;
    }
    const headsNum = parseInt(heads, 10);
    if (!headsNum || headsNum < 1) {
      setLocalError("Must have at least 1 head");
      return;
    }

    if (existingUserMode) {
      setLocalError("");
      setSubmitting(true);
      try {
        const ok = await completeProfile({ name: trimmedName, contactNumber: contact.trim() || undefined });
        if (ok) {
          navigate("/member/dashboard");
        } else {
          setLocalError("Failed to save. Please try again.");
        }
      } catch {
        setLocalError("An unexpected error occurred");
      } finally {
        setSubmitting(false);
      }
      return;
    }

    const trimmedCode = code.trim();
    if (!trimmedCode) {
      setLocalError("Group code is required");
      return;
    }

    setLocalError("");
    clearError();
    setSubmitting(true);
    try {
      const result = await joinWithGroupCode(trimmedCode, {
        displayName: trimmedName,
        headsCount: headsNum,
        contactNumber: contact.trim() || undefined,
      });
      if (result.success) {
        setWelcome(true);
        setDisplayName(trimmedName);
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

  if (showPrompt && !existingUserMode) {
    return (
      <div className="app-login-page">
        <div className="app-login-card" style={{ textAlign: "center" }}>
          <div className="app-login-logo">
            <div className="app-login-logo-icon">💰</div>
            <h1 className="app-login-title">LendWUs</h1>
          </div>
          <div style={{ fontSize: 48, margin: "16px 0" }}>👥</div>
          <h2 style={{ color: "#fff", margin: "0 0 8px" }}>
            You're not with a group yet
          </h2>
          <p style={{ color: "#8b949e", marginBottom: 24, lineHeight: 1.5, maxWidth: 320, margin: "0 auto 24px" }}>
            After signing in, you need to join a savings group using a group code provided by your fund admin.
          </p>
          <button
            className="app-login-submit"
            onClick={() => setShowPrompt(false)}
            style={{ marginBottom: 12 }}
          >
            I Have a Group Code
          </button>
          <button
            className="app-login-google"
            onClick={handleLogout}
          >
            Log Out / Exit
          </button>
          <div className="app-login-footer">
            <a href="/member/login">Back to Sign In</a>
          </div>
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
          <p className="app-login-subtitle">{existingUserMode ? "Complete Profile" : "Setup"}</p>
        </div>

        <div style={{ fontSize: 48, textAlign: "center", margin: "8px 0" }}>
          {existingUserMode ? "✏️" : "📝"}
        </div>
        <h2 style={{ color: "#fff", textAlign: "center", margin: "0 0 4px", fontSize: 20 }}>
          {existingUserMode ? "Complete Your Profile" : "Complete Your Setup"}
        </h2>
        <p style={{ color: "#8b949e", textAlign: "center", marginBottom: 20, fontSize: 14 }}>
          {existingUserMode
            ? "Please provide your display name and contact number to continue."
            : "Fill in your details to join the savings fund."}
        </p>

        {(localError || error) && <div className="form-error">{localError || error}</div>}

        <form onSubmit={e => { e.preventDefault(); handleJoin(); }}>
          <div className="app-login-input-group">
            <span className="app-login-input-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </svg>
            </span>
            <input
              type="text"
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Display Name"
              disabled={submitting}
              className="app-login-input"
              required
            />
          </div>

          <div className="app-login-input-group" style={{ marginTop: 12 }}>
            <span className="app-login-input-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </span>
            <input
              type="number"
              value={heads}
              onChange={e => setHeads(e.target.value)}
              placeholder="Number of Heads"
              disabled={submitting || existingUserMode}
              className="app-login-input"
              min="1"
              required
            />
          </div>
          <p style={{ color: "#8b949e", fontSize: 11, margin: "2px 0 0 42px" }}>
            {existingUserMode
              ? "To change your head count, submit a head change request."
              : "Each head = one share. You can change this later."}
          </p>

          <div className="app-login-input-group" style={{ marginTop: 12 }}>
            <span className="app-login-input-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
              </svg>
            </span>
            <input
              type="tel"
              value={contact}
              onChange={e => setContact(e.target.value)}
              placeholder="Contact Number (optional)"
              disabled={submitting}
              className="app-login-input"
            />
          </div>

          {!existingUserMode && (
            <>
              <div className="app-login-input-group" style={{ marginTop: 12 }}>
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
                  placeholder="Group Code"
                  style={{ textTransform: "uppercase" }}
                  disabled={submitting}
                  className="app-login-input"
                  required
                />
              </div>
              <p style={{ color: "#8b949e", fontSize: 11, margin: "2px 0 0 42px" }}>
                Ask the fund admin for the group code to join.
              </p>
            </>
          )}

          <button
            type="submit"
            className="app-login-submit"
            disabled={submitting || !name.trim() || (existingUserMode ? false : !code.trim())}
          >
            {submitting ? "Saving..." : existingUserMode ? "Save" : "Join Group"}
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
