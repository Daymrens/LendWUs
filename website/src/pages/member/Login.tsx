import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useMemberAuth } from "../../context/MemberAuthContext";
import { Mail, Lock, Eye, EyeOff } from "lucide-react";

const MemberLogin: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [localError, setLocalError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const { login, signInWithGoogle } = useMemberAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLocalError("");
    setSubmitting(true);
    try {
      const result = await login(email, password);
      if (result.success) {
        navigate("/member/dashboard");
      } else {
        setLocalError(result.error || "Login failed");
      }
    } catch {
      setLocalError("An unexpected error occurred");
    } finally {
      setSubmitting(false);
    }
  };

  const handleGoogleSignIn = async () => {
    setLocalError("");
    setSubmitting(true);
    try {
      const result = await signInWithGoogle();
      if (result.success) {
        navigate("/member/dashboard");
      } else {
        setLocalError(result.error || "Google sign-in failed");
      }
    } catch {
      setLocalError("An unexpected error occurred");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="split-login">
      {/* Left Panel — Form */}
      <div className="split-login-form">
        <div className="bg-pattern" />
        <div className="bg-gradient-blur" />
        <div className="split-login-form-inner">
          <h1 className="split-login-heading">LOGIN</h1>
          <p className="split-login-sub">
            Welcome back! Sign in to manage your savings, loans, and fund contributions.
          </p>

          {localError && <div className="split-login-error">{localError}</div>}

          <form onSubmit={handleSubmit}>
            <div className="split-login-field">
              <span className="split-login-field-icon"><Mail size={18} /></span>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="Username"
                required
                className="split-login-input"
              />
            </div>

            <div className="split-login-field" style={{ marginTop: 16 }}>
              <span className="split-login-field-icon"><Lock size={18} /></span>
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="Password"
                required
                className="split-login-input"
              />
              <button
                type="button"
                className="split-login-eye"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>

            <button type="submit" className="split-login-btn" disabled={submitting}>
              {submitting ? "Signing in..." : "Login Now"}
            </button>
          </form>

          <div className="split-login-divider"><span>or continue with</span></div>

          <div className="split-login-social">
            <button className="split-login-social-btn" onClick={handleGoogleSignIn} disabled={submitting}>
              <svg width="20" height="20" viewBox="0 0 24 24">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
              </svg>
              Google
            </button>
          </div>

          <div className="split-login-links">
            <a href="/member/unrecognized">New member? Enter group code</a>
            <a href="/">Back to Home</a>
          </div>
        </div>
      </div>

      {/* Right Panel — Decorative */}
      <div className="split-login-hero">
        <div className="split-login-hero-glow" />
        <div className="split-login-hero-line" />
        <div className="bg-pattern" />
        <div className="split-login-hero-content">
          <div className="split-login-hero-icon">
            <img src="/icons/icon.png" alt="LendWUs" width="180" height="180" />
          </div>
          <h2 className="split-login-hero-title">LendWUs</h2>
          <p className="split-login-hero-desc">
            Track contributions, apply for loans, and monitor your fund growth.
          </p>
          <div className="split-login-hero-features">
            <div className="split-login-hero-feature">
              <span className="split-login-hero-feature-dot" />
              Smart savings tracking
            </div>
            <div className="split-login-hero-feature">
              <span className="split-login-hero-feature-dot" />
              Easy loan management
            </div>
            <div className="split-login-hero-feature">
              <span className="split-login-hero-feature-dot" />
              Real-time fund insights
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default MemberLogin;
