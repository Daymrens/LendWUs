import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { sendPasswordResetEmail } from "firebase/auth";
import { auth } from "../firebase";
import { useAuth } from "../context/AuthContext";
import { Eye, EyeOff, Lock, AtSign } from "lucide-react";

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
      <div className="app-login-card">
        <div className="app-login-logo">
          <div className="app-login-logo-icon">
            💰
          </div>
          <h1 className="app-login-title">LendWUs</h1>
          <p className="app-login-subtitle">Financial management simplified</p>
        </div>

        {(localError || authError) && <div className="form-error">{localError || authError}</div>}
        {resetSent && <div className="form-success" style={{ color: "#22c55e", fontSize: 13, marginBottom: 16, textAlign: "center" }}>Reset link sent! Check your email.</div>}

        <form onSubmit={handleSubmit} className="app-login-form">
          <div className="app-login-input-group">
            <span className="app-login-input-icon"><AtSign size={18} /></span>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="Email Address"
              required
              className="app-login-input"
            />
          </div>

          <div className="app-login-input-group">
            <span className="app-login-input-icon"><Lock size={18} /></span>
            <input
              type={showPassword ? "text" : "password"}
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="Password"
              required
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

          <div className="app-login-forgot">
            <button type="button" onClick={handleForgotPassword} className="app-login-forgot-btn">
              Forgot password?
            </button>
          </div>

          <button type="submit" className="app-login-submit" disabled={submitting}>
            {submitting ? "Signing in..." : "Sign In"}
          </button>
        </form>

        <div className="app-login-divider">
          <span>OR CONTINUE WITH</span>
        </div>

        <button
          type="button"
          className="app-login-google"
          onClick={handleGoogleSignIn}
          disabled={submitting}
        >
          <svg width="20" height="20" viewBox="0 0 24 24">
            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
          </svg>
          Sign in with Google
        </button>

        <div className="app-login-footer">
          <a href="/member/unrecognized">New member? Enter group code</a>
          <a href="/" className="app-login-back">Back to Home</a>
        </div>
      </div>
    </div>
  );
};

export default Login;
