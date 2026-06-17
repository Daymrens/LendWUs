import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { sendPasswordResetEmail } from "firebase/auth";
import { auth } from "../firebase";
import { useAuth } from "../context/AuthContext";
import { Eye, EyeOff, Mail, Lock, ArrowRight, CheckCircle } from "lucide-react";

const Login: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [localError, setLocalError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [resetSent, setResetSent] = useState(false);
  const { login, signInWithGoogle, error: authError } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLocalError("");
    setSubmitting(true);
    try {
      const result = await login(email, password);
      if (result.success) {
        navigate(result.role === "admin" ? "/admin/dashboard" : "/member/dashboard");
      } else {
        setLocalError(result.error || "Login failed");
      }
    } catch {
      setLocalError("An unexpected error occurred");
    } finally {
      setSubmitting(false);
    }
  };

  const handleForgotPassword = async () => {
    if (!email) {
      setLocalError("Enter your email address first.");
      return;
    }
    setLocalError("");
    setResetSent(false);
    try {
      await sendPasswordResetEmail(auth, email);
      setResetSent(true);
    } catch {
      setLocalError("Failed to send reset email. Check the address and try again.");
    }
  };

  const handleGoogleSignIn = async () => {
    setLocalError("");
    setSubmitting(true);
    try {
      const result = await signInWithGoogle();
      if (result.success) {
        navigate(result.role === "admin" ? "/admin/dashboard" : "/member/dashboard");
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
    <div className="app-login-page">
      <div className="app-login-shell">
        {/* Left Panel — Form */}
        <div className="app-login-panel-left">
          <a href="/" className="logo" style={{ marginBottom: 40 }}>Lend<span>WUs</span></a>

          <p className="app-login-eyebrow">Welcome back</p>
          <h1 className="app-login-heading">Sign in to LendWUs</h1>

          {(localError || authError) && (
            <div className="app-login-error">{localError || authError}</div>
          )}
          {resetSent && (
            <div className="app-login-success">Reset link sent! Check your email.</div>
          )}

          <form onSubmit={handleSubmit}>
            <div className="app-login-field">
              <label htmlFor="login-email">Email</label>
              <div className="app-login-input-group">
                <span className="app-login-input-icon"><Mail size={18} /></span>
                <input
                  id="login-email"
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  autoComplete="email"
                  autoFocus
                  className="app-login-input"
                />
              </div>
            </div>

            <div className="app-login-field">
              <div className="app-login-field-row">
                <label htmlFor="login-password">Password</label>
                <button type="button" className="app-login-forgot-btn" onClick={handleForgotPassword}>
                  Forgot password?
                </button>
              </div>
              <div className="app-login-input-group">
                <span className="app-login-input-icon"><Lock size={18} /></span>
                <input
                  id="login-password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="Enter your password"
                  required
                  autoComplete="current-password"
                  className="app-login-input"
                />
                <button
                  type="button"
                  className="app-login-eye-btn"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            <button type="submit" className="app-login-submit" disabled={submitting}>
              {submitting ? <><span className="app-login-spinner" /> Signing in…</> : <><span>Sign In</span><ArrowRight size={18} /></>}
            </button>
          </form>

          <div className="app-login-divider">or continue with</div>

          <button className="app-login-google" onClick={handleGoogleSignIn} disabled={submitting}>
            <svg width="20" height="20" viewBox="0 0 24 24">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
            </svg>
            Google
          </button>

          <div className="app-login-footer">
            New here? <a href="/member/unrecognized">Enter group code</a> · <a href="/">Back to Home</a>
          </div>
        </div>

        {/* Right Panel — Brand Visual */}
        <div className="app-login-panel-right" aria-hidden="true">
          <div className="app-login-brand-glow" />
          <div className="app-login-brand-dots" />
          <div className="app-login-brand-gradient" />

          {/* Phone frame — static Dashboard screen */}
          <div className="phone-mockup" aria-hidden="true">
            {/* Floating badges inside phone frame so positioning is relative to it */}
            <div className="phone-float-badge badge-1" aria-hidden="true">
              <span className="float-badge-icon">💰</span>
              <span className="float-badge-value">₱124.5K</span>
              <span className="float-badge-label">Total Fund</span>
            </div>
            <div className="phone-float-badge badge-3" aria-hidden="true">
              <span className="float-badge-icon">📈</span>
              <span className="float-badge-value">+₱2.2K</span>
              <span className="float-badge-label">Interest</span>
            </div>
            <div className="phone-buttons-left" />
            <div className="phone-button-right" />
            <div className="phone-screen">
              <div className="mockup-screen active">
                <div className="app-header">
                  <div className="app-title">Dashboard</div>
                  <div className="user-avatar" />
                </div>
                <div className="app-stats">
                  <div className="stat-card gradient-1">
                    <div className="stat-label">Total Fund</div>
                    <div className="stat-value">₱124,500.00</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-label">Active Members</div>
                    <div className="stat-value">12</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-label">Total Loans</div>
                    <div className="stat-value">₱45,000.00</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-label">Interest Earned</div>
                    <div className="stat-value">₱2,250.00</div>
                  </div>
                </div>
                <div className="preview-section-title">Recent Activity</div>
                <div className="app-list">
                  {[
                    { title: 'Loan Repayment', sub: 'Approved • Juan', amount: '+₱1,500', type: 'success' },
                    { title: 'New Contribution', sub: 'Pending • Maria', amount: '+₱500', type: 'pending' },
                    { title: 'Loan Issued', sub: 'Active • Pedro', amount: '-₱5,000', type: 'error' }
                  ].map((item, i) => (
                    <div key={i} className="list-item">
                      <div className={`item-icon ${item.type}`} />
                      <div className="item-info">
                        <div className="item-title">{item.title}</div>
                        <div className="item-subtitle">{item.sub}</div>
                      </div>
                      <div className={`item-amount ${item.type === 'success' ? 'text-success' : item.type === 'error' ? 'text-error' : 'text-pending'}`}>
                        {item.amount}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
            <div className="phone-home-indicator" />
          </div>

          {/* Trust row */}
          <div className="app-login-trust">
            <div className="app-login-trust-item"><CheckCircle size={14} /> Secure &amp; Private</div>
            <div className="app-login-trust-item"><CheckCircle size={14} /> Real-time Sync</div>
            <div className="app-login-trust-item"><CheckCircle size={14} /> No Hidden Fees</div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
