import React from "react";

const About: React.FC = () => {
  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>About</h1>
      </div>

      <div style={{ textAlign: "center", marginBottom: 32 }}>
        <div style={{
          width: 80, height: 80, borderRadius: 20,
          background: "linear-gradient(135deg, #1a4d2e, #0d2818)",
          display: "flex", alignItems: "center", justifyContent: "center",
          margin: "0 auto 16px", fontSize: 32, fontWeight: 800, color: "#fff",
        }}>
          LW
        </div>
        <h2 style={{ color: "#fff", margin: "0 0 4px" }}>LendWUs</h2>
        <div style={{ color: "#8b949e", fontSize: 13 }}>Version 2.1.0</div>
      </div>

      <div className="settings-section">
        <h2>About</h2>
        <p style={{ color: "#8b949e", fontSize: 14, lineHeight: 1.6, margin: 0 }}>
          LendWUs is a group savings and loan management application designed for community-based financial groups.
          It enables transparent tracking of contributions, loan issuance, repayments, and automated interest calculations.
        </p>
      </div>

      <div className="settings-section">
        <h2>Features</h2>
        <ul className="feature-list">
          <li>💰 Contribution tracking with receipt upload</li>
          <li>🏦 Group savings pool management</li>
          <li>📋 Loan issuance and repayment tracking</li>
          <li>📊 Monthly reports and fund growth charts</li>
          <li>🔔 Real-time notifications</li>
        </ul>
      </div>

      <div className="settings-section">
        <h2>Legal</h2>
        <div className="member-card" style={{ marginBottom: 8 }}>
          <div className="member-info">
            <div className="member-name"><span>📜 Terms of Service</span></div>
          </div>
        </div>
        <div className="member-card" style={{ marginBottom: 8 }}>
          <div className="member-info">
            <div className="member-name"><span>🔒 Privacy Policy</span></div>
          </div>
        </div>
        <div className="member-card">
          <div className="member-info">
            <div className="member-name"><span>📝 Licenses</span></div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default About;
