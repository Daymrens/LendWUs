import React, { useEffect, useState } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "../firebase";

const MaintenanceScreen: React.FC = () => {
  const [message, setMessage] = useState("The system is currently undergoing maintenance. Please check back later.");
  const [contactEmail, setContactEmail] = useState("");

  useEffect(() => {
    getDoc(doc(db, "app_settings", "fund_settings")).then(snap => {
      if (!snap.exists()) return;
      const data = snap.data();
      if (data.maintenanceMessage) setMessage(data.maintenanceMessage);
      if (data.contactEmail) setContactEmail(data.contactEmail);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      getDoc(doc(db, "app_settings", "fund_settings")).then(snap => {
        if (snap.exists() && !snap.data().isMaintenanceMode) {
          window.location.reload();
        }
      }).catch(() => {});
    }, 30000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="maintenance-container">
      <div className="maintenance-bg-shapes">
        <div className="maintenance-shape maintenance-shape-1" />
        <div className="maintenance-shape maintenance-shape-2" />
        <div className="maintenance-shape maintenance-shape-3" />
      </div>
      <div className="maintenance-card">
        <div className="maintenance-status-bar">
          <span className="maintenance-pulse" />
          Scheduled Maintenance
        </div>
        <div className="maintenance-icon-wrap">
          <svg className="maintenance-anim-icon" width="72" height="72" viewBox="0 0 24 24" fill="none" stroke="#e74c3c" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
          </svg>
        </div>
        <h1>Under Maintenance</h1>
        <p className="maintenance-message">{message}</p>
        <div className="maintenance-divider" />
        <div className="maintenance-footer">
          <div className="maintenance-info">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            We'll be back shortly
          </div>
          {contactEmail && (
            <div className="maintenance-info">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
              {contactEmail}
            </div>
          )}
        </div>
        <div className="maintenance-refresh">
          Auto-checking every 30s
          <span className="maintenance-dots">
            <span className="dot-1">.</span>
            <span className="dot-2">.</span>
            <span className="dot-3">.</span>
          </span>
        </div>
      </div>
    </div>
  );
};

export default MaintenanceScreen;
