import React, { useEffect, useState, useRef, useCallback } from "react";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { getStorage, ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { db } from "../../firebase";

interface AppSettings {
  minPaymentPerHead: number;
  maxPaymentPerHead: number;
  loanInterestPercent: number;
  currencySymbol: string;
  currencyCode: string;
  cutoffDay1: number;
  cutoffDay2: number;
  adminEmails: string[];
  treasurerEmails: string[];
  qrAccountName: string;
  qrAccountNumber: string;
  qrImageUrl: string;
  apkDownloadUrl: string;
  apkVersion: string;
  contactEmail: string;
  contactPhone: string;
  downloadCount: number;
  isMaintenanceMode: boolean;
  maintenanceMessage: string;
}

const currencies = [
  { code: "PHP", symbol: "\u20B1" },
  { code: "USD", symbol: "$" },
  { code: "EUR", symbol: "\u20AC" },
  { code: "GBP", symbol: "\u00A3" },
  { code: "JPY", symbol: "\u00A5" },
  { code: "KRW", symbol: "\u20A9" },
  { code: "INR", symbol: "\u20B9" },
];

const DEFAULT_SETTINGS: AppSettings = {
  minPaymentPerHead: 150,
  maxPaymentPerHead: 1000,
  loanInterestPercent: 10,
  currencySymbol: "\u20B1",
  currencyCode: "PHP",
  cutoffDay1: 13,
  cutoffDay2: 28,
  adminEmails: [],
  treasurerEmails: [],
  qrAccountName: "",
  qrAccountNumber: "",
  qrImageUrl: "",
  apkDownloadUrl: "",
  apkVersion: "",
  contactEmail: "",
  contactPhone: "",
  downloadCount: 0,
  isMaintenanceMode: false,
  maintenanceMessage: "",
};

const SECTIONS = [
  { id: "limits", label: "Payment Limits", icon: "\u{1F4B1}" },
  { id: "currency", label: "Currency", icon: "\u{1F4B6}" },
  { id: "interest", label: "Loan Interest", icon: "\u{1F4C8}" },
  { id: "cutoffs", label: "Cutoff Dates", icon: "\u{1F4C5}" },
  { id: "qr", label: "QR Payment", icon: "\u{1F4F7}" },
  { id: "apk", label: "APK Download", icon: "\u{1F4E5}" },
  { id: "contact", label: "Contact Info", icon: "\u{1F4DE}" },
  { id: "maintenance", label: "Maintenance", icon: "\u26A0\uFE0F" },
  { id: "admins", label: "Admin Emails", icon: "\u{1F464}" },
  { id: "treasurer", label: "Treasurers", icon: "\u{1F3E6}" },
];

const Settings: React.FC = () => {
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [original, setOriginal] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [newAdminEmail, setNewAdminEmail] = useState("");
  const [newTreasurerEmail, setNewTreasurerEmail] = useState("");
  const [activeSection, setActiveSection] = useState("limits");
  const sectionRefs = useRef<Record<string, HTMLDivElement | null>>({});

  useEffect(() => {
    const load = async () => {
      try {
        const snap = await getDoc(doc(db, "app_settings", "fund_settings"));
        if (snap.exists()) {
          const data = { ...DEFAULT_SETTINGS, ...snap.data() } as AppSettings;
          setSettings(data);
          setOriginal(data);
        }
      } catch { /* ignore */ }
      finally { setLoading(false); }
    };
    load();
  }, []);

  const hasChanges = JSON.stringify(settings) !== JSON.stringify(original);

  const handleSave = async () => {
    setSaving(true);
    setMessage(null);
    try {
      await setDoc(doc(db, "app_settings", "fund_settings"), settings);
      setOriginal({ ...settings });
      setMessage({ ok: true, text: "Settings saved successfully" });
    } catch (err: unknown) {
      setMessage({ ok: false, text: err instanceof Error ? err.message : "Failed to save" });
    } finally {
      setSaving(false);
    }
  };

  const set = <K extends keyof AppSettings>(key: K, value: AppSettings[K]) => {
    setSettings(prev => ({ ...prev, [key]: value }));
  };

  const addAdminEmail = () => {
    const email = newAdminEmail.trim().toLowerCase();
    if (!email) return;
    if (settings.adminEmails.includes(email)) return;
    set("adminEmails", [...settings.adminEmails, email]);
    setNewAdminEmail("");
  };

  const removeAdminEmail = (email: string) => {
    set("adminEmails", settings.adminEmails.filter(e => e !== email));
  };

  const addTreasurerEmail = () => {
    const email = newTreasurerEmail.trim().toLowerCase();
    if (!email) return;
    if (settings.treasurerEmails.includes(email)) return;
    set("treasurerEmails", [...settings.treasurerEmails, email]);
    setNewTreasurerEmail("");
  };

  const removeTreasurerEmail = (email: string) => {
    set("treasurerEmails", settings.treasurerEmails.filter(e => e !== email));
  };

  const handleQRImage = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      setMessage(null);
      const storage = getStorage();
      const storageRef = ref(storage, `qr_codes/${file.name}`);
      const snapshot = await uploadBytes(storageRef, file);
      const downloadUrl = await getDownloadURL(snapshot.ref);
      set("qrImageUrl", downloadUrl);
      setMessage({ ok: true, text: "QR code uploaded to storage" });
    } catch {
      const reader = new FileReader();
      reader.onloadend = () => {
        if (typeof reader.result === "string") {
          set("qrImageUrl", reader.result);
          setMessage({ ok: true, text: "QR code saved as base64 (Spark plan fallback)" });
        }
      };
      reader.readAsDataURL(file);
    }
  };

  const scrollTo = useCallback((id: string) => {
    setActiveSection(id);
    sectionRefs.current[id]?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, []);

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading settings...</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Admin Settings</h1>
        <button className="btn btn-primary btn-sm" onClick={handleSave} disabled={saving || !hasChanges}>
          {saving ? "Saving..." : hasChanges ? "Save Changes" : "Saved"}
        </button>
      </div>

      {message && (
        <div className={`send-notif-result ${message.ok ? "success" : "error"}`} style={{ marginBottom: 16 }}>
          {message.ok ? "\u2705" : "\u26A0\uFE0F"} {message.text}
        </div>
      )}

      {hasChanges && (
        <div className="unsaved-bar">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
          You have unsaved changes
        </div>
      )}

      <div className="settings-layout">
        <nav className="settings-nav">
          {SECTIONS.map(s => (
            <button
              key={s.id}
              className={`settings-nav-btn ${activeSection === s.id ? "active" : ""}`}
              onClick={() => scrollTo(s.id)}
            >
              <span className="settings-nav-icon">{s.icon}</span>
              <span className="settings-nav-label">{s.label}</span>
            </button>
          ))}
        </nav>

        <div className="settings-form">
          <div ref={el => sectionRefs.current["limits"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[0].icon}</span>
              <h2>Payment per Head Limits</h2>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>Minimum ({settings.currencySymbol})</label>
                <input type="number" min="0" step="0.01" value={settings.minPaymentPerHead} onChange={e => set("minPaymentPerHead", Number(e.target.value))} />
              </div>
              <div className="form-group">
                <label>Maximum ({settings.currencySymbol})</label>
                <input type="number" min="0" step="0.01" value={settings.maxPaymentPerHead} onChange={e => set("maxPaymentPerHead", Number(e.target.value))} />
              </div>
            </div>
          </div>

          <div ref={el => sectionRefs.current["currency"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[1].icon}</span>
              <h2>Currency Settings</h2>
            </div>
            <div className="form-group">
              <label>Select Currency</label>
              <select value={settings.currencyCode} onChange={e => {
                const c = currencies.find(c => c.code === e.target.value);
                if (c) setSettings(prev => ({ ...prev, currencyCode: c.code, currencySymbol: c.symbol }));
              }}>
                {currencies.map(c => (
                  <option key={c.code} value={c.code}>{c.code} ({c.symbol})</option>
                ))}
              </select>
            </div>
          </div>

          <div ref={el => sectionRefs.current["interest"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[2].icon}</span>
              <h2>Loan Interest</h2>
            </div>
            <div className="form-group">
              <label>Interest Rate (%)</label>
              <input type="number" min="0" step="0.1" value={settings.loanInterestPercent} onChange={e => set("loanInterestPercent", Number(e.target.value))} />
              <span className="form-hint">Default interest rate for new loans</span>
            </div>
          </div>

          <div ref={el => sectionRefs.current["cutoffs"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[3].icon}</span>
              <h2>Monthly Cutoff Dates</h2>
            </div>
            <p className="form-hint" style={{ marginBottom: 12 }}>Payments are due on these days each month.</p>
            <div className="form-row">
              <div className="form-group">
                <label>1st Cutoff Day</label>
                <input type="number" min="1" max="31" value={settings.cutoffDay1} onChange={e => set("cutoffDay1", Number(e.target.value))} />
              </div>
              <div className="form-group">
                <label>2nd Cutoff Day</label>
                <input type="number" min="1" max="31" value={settings.cutoffDay2} onChange={e => set("cutoffDay2", Number(e.target.value))} />
              </div>
            </div>
          </div>

          <div ref={el => sectionRefs.current["qr"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[4].icon}</span>
              <h2>QR Payment Info</h2>
            </div>
            <p className="form-hint" style={{ marginBottom: 12 }}>Members see this when paying contributions.</p>
            <div className="form-group">
              <label>Account Name</label>
              <input type="text" value={settings.qrAccountName} onChange={e => set("qrAccountName", e.target.value)} placeholder="e.g. LendWUs Group Fund" />
            </div>
            <div className="form-group">
              <label>Account Number</label>
              <input type="text" value={settings.qrAccountNumber} onChange={e => set("qrAccountNumber", e.target.value)} placeholder="e.g. 09123456789" />
            </div>
            <div className="form-group">
              <label>QR Code Image</label>
              {settings.qrImageUrl ? (
                <div className="qr-preview">
                  <img src={settings.qrImageUrl} alt="QR Code" className="qr-preview-img" />
                  <button type="button" className="btn btn-outline btn-sm" onClick={() => set("qrImageUrl", "")} style={{ color: "#ef4444", borderColor: "#ef4444" }}>Remove QR</button>
                </div>
              ) : (
                <label className="btn btn-outline btn-sm" style={{ cursor: "pointer", display: "inline-flex", alignItems: "center", gap: 6 }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>
                  Upload QR Code Image
                  <input type="file" accept="image/*" onChange={handleQRImage} style={{ display: "none" }} />
                </label>
              )}
            </div>
          </div>

          <div ref={el => sectionRefs.current["apk"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[5].icon}</span>
              <h2>APK Download</h2>
            </div>
            <p className="form-hint" style={{ marginBottom: 12 }}>Configure the Android APK download link and version shown on the landing page.</p>
            <div className="form-group">
              <label>APK Download URL</label>
              <input type="url" value={settings.apkDownloadUrl} onChange={e => set("apkDownloadUrl", e.target.value)} placeholder="e.g. https://www.mediafire.com/file/..." />
            </div>
            <div className="form-group">
              <label>APK Version</label>
              <input type="text" value={settings.apkVersion} onChange={e => set("apkVersion", e.target.value)} placeholder="e.g. v3.1" />
            </div>
            <div className="form-group">
              <label>Download Count</label>
              <div className="download-count-display">{settings.downloadCount ?? 0}</div>
              <span className="form-hint">Total APK downloads (auto-tracked)</span>
            </div>
          </div>

          <div ref={el => sectionRefs.current["contact"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[6].icon}</span>
              <h2>Contact Information</h2>
            </div>
            <p className="form-hint" style={{ marginBottom: 12 }}>Shown in the footer of the landing page.</p>
            <div className="form-group">
              <label>Contact Email</label>
              <input type="email" value={settings.contactEmail} onChange={e => set("contactEmail", e.target.value)} placeholder="e.g. support@lendwus.com" />
            </div>
            <div className="form-group">
              <label>Contact Phone</label>
              <input type="tel" value={settings.contactPhone} onChange={e => set("contactPhone", e.target.value)} placeholder="e.g. +63 991 718 5691" />
            </div>
          </div>

          <div ref={el => sectionRefs.current["maintenance"] = el} className="settings-section" style={{ borderColor: settings.isMaintenanceMode ? "#e74c3c" : undefined }}>
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[7].icon}</span>
              <h2 style={{ color: settings.isMaintenanceMode ? "#e74c3c" : undefined }}>Maintenance Mode</h2>
            </div>
            <p className="form-hint" style={{ marginBottom: 12 }}>When enabled, members will see a maintenance screen and cannot use the app.</p>
            <div className="form-group">
              <label className="switch-label">
                <input type="checkbox" checked={settings.isMaintenanceMode} onChange={e => set("isMaintenanceMode", e.target.checked)} />
                <span className="switch-slider" />
                <span style={{ marginLeft: 10, fontWeight: 600 }}>Enable Maintenance Mode</span>
              </label>
            </div>
            {settings.isMaintenanceMode && (
              <div className="form-group">
                <label>Maintenance Message</label>
                <textarea className="send-notif-textarea" value={settings.maintenanceMessage} onChange={e => set("maintenanceMessage", e.target.value)} placeholder="Message shown to members (optional)" rows={3} />
              </div>
            )}
          </div>

          <div ref={el => sectionRefs.current["admins"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[8].icon}</span>
              <h2>Admin Emails</h2>
            </div>
            <p className="form-hint" style={{ marginBottom: 12 }}>Users with these emails are recognized as admins on login.</p>
            <div className="admin-email-row">
              <input type="email" value={newAdminEmail} onChange={e => setNewAdminEmail(e.target.value)} placeholder="admin@example.com" onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); addAdminEmail(); } }} />
              <button type="button" className="btn btn-primary btn-sm" onClick={addAdminEmail}>Add</button>
            </div>
            {settings.adminEmails.length === 0 ? (
              <span className="form-hint">No admin emails configured.</span>
            ) : (
              <div className="admin-emails-list">
                {settings.adminEmails.map(email => (
                  <span key={email} className="admin-email-chip">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                    {email}
                    <button type="button" onClick={() => removeAdminEmail(email)} title="Remove">&times;</button>
                  </span>
                ))}
              </div>
            )}
          </div>

          <div ref={el => sectionRefs.current["treasurer"] = el} className="settings-section">
            <div className="settings-section-header">
              <span className="settings-section-icon">{SECTIONS[9].icon}</span>
              <h2>Treasurer Emails</h2>
            </div>
            <p className="form-hint" style={{ marginBottom: 12 }}>Users with these emails receive notifications for payment requests and can confirm bank receipt. They cannot approve requests — only admins can.</p>
            <div className="admin-email-row">
              <input type="email" value={newTreasurerEmail} onChange={e => setNewTreasurerEmail(e.target.value)} placeholder="treasurer@example.com" onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); addTreasurerEmail(); } }} />
              <button type="button" className="btn btn-primary btn-sm" onClick={addTreasurerEmail}>Add</button>
            </div>
            {settings.treasurerEmails.length === 0 ? (
              <span className="form-hint">No treasurer emails configured.</span>
            ) : (
              <div className="admin-emails-list">
                {settings.treasurerEmails.map(email => (
                  <span key={email} className="admin-email-chip">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                    {email}
                    <button type="button" onClick={() => removeTreasurerEmail(email)} title="Remove">&times;</button>
                  </span>
                ))}
              </div>
            )}
          </div>

          <div className="settings-sticky-bar">
            <div className="settings-sticky-info">
              {hasChanges && <span className="unsaved-dot" />}
              <span>{hasChanges ? "Unsaved changes" : "All changes saved"}</span>
            </div>
            <button className="btn btn-primary" onClick={handleSave} disabled={saving || !hasChanges}>
              {saving ? "Saving..." : "Save Settings"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Settings;
