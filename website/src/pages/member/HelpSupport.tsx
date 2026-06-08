import React, { useState } from "react";

const faqItems = [
  {
    q: "How do contributions work?",
    a: "Each member has a required amount per head. You submit your contribution via the app, upload a receipt, and an admin approves it. Your total contributions are tracked in real-time.",
  },
  {
    q: "How are loans processed?",
    a: "Submit a loan request with the amount and purpose. An admin reviews and approves it based on fund availability. Interest is applied to the repayment amount.",
  },
  {
    q: "What are the cutoff dates?",
    a: "Cutoff dates are set by the admin (usually two per month). These determine when contributions are due. You can see your next cutoff on the dashboard.",
  },
  {
    q: "Can I change my number of heads?",
    a: "Yes! Go to your Dashboard and tap 'Change Heads'. Submit a request and an admin will review it. Your contribution amount will adjust accordingly.",
  },
  {
    q: "How is my credit balance calculated?",
    a: "If you contribute more than your required amount in a given month, the excess is credited to your account and applied to future contributions.",
  },
];

const HelpSupport: React.FC = () => {
  const [openFaq, setOpenFaq] = useState<number | null>(null);

  const copyEmail = () => {
    navigator.clipboard.writeText("support@lendwus.com");
    alert("Email address copied to clipboard!");
  };

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Help & Support</h1>
      </div>

      <div style={{ textAlign: "center", marginBottom: 32 }}>
        <div style={{ fontSize: 48, marginBottom: 12 }}>🆘</div>
        <h2 style={{ color: "#fff", marginBottom: 8 }}>How can we help you?</h2>
      </div>

      <div className="settings-section">
        <h2>Contact Us</h2>
        <div
          className="member-card"
          style={{ cursor: "pointer", marginBottom: 8 }}
          onClick={copyEmail}
        >
          <div className="member-info">
            <div className="member-name">
              <span>📧 Email Us</span>
            </div>
            <div className="member-details">
              <span>support@lendwus.com</span>
            </div>
          </div>
        </div>
        <div className="member-card" style={{ opacity: 0.6 }}>
          <div className="member-info">
            <div className="member-name">
              <span>💬 Live Chat</span>
            </div>
            <div className="member-details">
              <span>Available Mon-Fri 9AM-6PM</span>
            </div>
          </div>
        </div>
      </div>

      <div className="settings-section">
        <h2>Frequently Asked Questions</h2>
        {faqItems.map((item, i) => (
          <div key={i} style={{ marginBottom: 8 }}>
            <button
              className="member-card"
              style={{ width: "100%", textAlign: "left", cursor: "pointer", border: "none" }}
              onClick={() => setOpenFaq(openFaq === i ? null : i)}
            >
              <div className="member-info">
                <div className="member-name">
                  <span>{item.q}</span>
                </div>
              </div>
            </button>
            {openFaq === i && (
              <div style={{
                padding: "12px 16px", background: "#0d1117",
                borderRadius: "0 0 10px 10px", fontSize: 13, color: "#8b949e",
                lineHeight: 1.6,
              }}>
                {item.a}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default HelpSupport;
