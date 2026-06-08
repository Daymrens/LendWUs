import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { sendPasswordResetEmail } from "firebase/auth";
import { auth } from "../firebase";
import { useAuth } from "../context/AuthContext";

const Login: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [localError, setLocalError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [resetSent, setResetSent] = useState(false);
  const { login, signInWithGoogle } = useAuth();
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
    <div className="login-page">
      <div className="login-card">
        <div className="login-logo">
          <span className="logo-text">Lend<span className="logo-accent">WUs</span></span>
          <span className="logo-sub">Sign In</span>
        </div>
        <form onSubmit={handleSubmit}>
          <h2>Welcome Back</h2>
          {localError && <div className="form-error">{localError}</div>}
          <div className="form-group">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="you@example.com"
              required
            />
          </div>
          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />
            <button
              type="button"
              className="btn-link"
              onClick={handleForgotPassword}
              style={{ fontSize: 13, marginTop: 4, padding: 0, border: "none", background: "none", color: "#22c55e", cursor: "pointer", textDecoration: "underline" }}
            >
              Forgot password?
            </button>
            {resetSent && <div className="form-success" style={{ color: "#22c55e", fontSize: 13, marginTop: 4 }}>Reset link sent! Check your email.</div>}
          </div>
          <button type="submit" className="btn btn-primary btn-block" disabled={submitting}>
            {submitting ? "Signing in..." : "Sign In"}
          </button>
          <div className="divider-row"><span>or</span></div>
          <button
            type="button"
            className="btn btn-google btn-block"
            onClick={handleGoogleSignIn}
            disabled={submitting}
          >
            <svg width="18" height="18" viewBox="0 0 48 48" style={{ marginRight: 8, verticalAlign: "middle" }}>
              <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
              <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
              <path fill="#FBBC05" d="M10.54 28.59A14.5 14.5 0 0 1 9.5 24c0-1.59.28-3.14.76-4.59l-7.98-6.19A23.99 23.99 0 0 0 0 24c0 3.77.87 7.35 2.56 10.56l7.98-5.97z"/>
              <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 5.97C6.51 42.62 14.62 48 24 48z"/>
            </svg>
            Sign in with Google
          </button>
        </form>
        <div className="login-footer-text">
          <span>New member? <a href="/member/unrecognized">Enter group code</a></span>
        </div>
        <a href="/" className="back-link">← Back to Home</a>
      </div>
    </div>
  );
};

export default Login;
