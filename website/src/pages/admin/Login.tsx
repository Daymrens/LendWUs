import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { ShieldCheck, TrendingUp, Users, DollarSign } from "lucide-react";

const Login: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [localError, setLocalError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLocalError("");
    setSubmitting(true);
    try {
      await login(email, password);
      navigate("/admin/dashboard");
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Login failed";
      setLocalError(message);
    } finally {
      setSubmitting(false);
    }
  };

  const features = [
    { icon: <ShieldCheck size={16} />, label: "Approval Workflow" },
    { icon: <TrendingUp size={16} />, label: "Real-time Reports" },
    { icon: <Users size={16} />, label: "Member Management" },
    { icon: <DollarSign size={16} />, label: "Financial Controls" },
  ];

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-header-bar">
          <div className="login-header-icon">
            <ShieldCheck size={24} />
          </div>
          <span className="login-header-title">Admin Panel</span>
          <span className="login-header-sub">LendWUs Group Fund Manager</span>
        </div>
        <div className="login-body">
          <form onSubmit={handleSubmit}>
            <h2>Sign In</h2>
            {localError && <div className="form-error">{localError}</div>}
            <div className="form-group">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="admin@example.com"
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
            </div>
            <button type="submit" className="btn btn-primary btn-block" disabled={submitting}>
              {submitting ? "Signing in..." : "Sign In"}
            </button>
          </form>
          <div className="login-features">
            {features.map((f, i) => (
              <div key={i} className="login-feature-chip">
                {f.icon} {f.label}
              </div>
            ))}
          </div>
        </div>
        <div className="login-footer-bar">
          <a href="/" className="back-link">← Back to Home</a>
          <span className="login-version">v2.1.0</span>
        </div>
      </div>
    </div>
  );
};

export default Login;
