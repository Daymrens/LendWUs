import React, { useEffect, useState } from "react";
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
  qrAccountName: string;
  qrAccountNumber: string;
  qrImageUrl: string;
  apkDownloadUrl: string;
  apkVersion: string;
  contactEmail: string;
  contactPhone: string;
  downloadCount: number;
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
  qrAccountName: "",
  qrAccountNumber: "",
  qrImageUrl: "",
  apkDownloadUrl: "",
  apkVersion: "",
  contactEmail: "",
  contactPhone: "",
  downloadCount: 0,
};

const Settings: React.FC = () => {
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [newAdminEmail, setNewAdminEmail] = useState("");

  useEffect(() => {
    const load = async () => {
      try {
        const snap = await getDoc(doc(db, "app_settings", "fund_settings"));
        if (snap.exists()) {
          setSettings({ ...DEFAULT_SETTINGS, ...snap.data() } as AppSettings);
        }
      } catch { /* ignore */ }
      finally { setLoading(false); }
    };
    load();
  }, []);

  const handleSave = async () => {
    setSaving(true);
    setMessage("");
    try {
      await setDoc(doc(db, "app_settings", "fund_settings"), settings);
      setMessage("Settings saved successfully");
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to save";
      setMessage("Error: " + msg);
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

  const handleQRImage = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      setMessage("");
      const storage = getStorage();
      const storageRef = ref(storage, `qr_codes/${file.name}`);
      const snapshot = await uploadBytes(storageRef, file);
      const downloadUrl = await getDownloadURL(snapshot.ref);
      set("qrImageUrl", downloadUrl);
      setMessage("QR code uploaded to storage");
    } catch {
      const reader = new FileReader();
      reader.onloadend = () => {
        if (typeof reader.result === "string") {
          set("qrImageUrl", reader.result);
          setMessage("QR code saved as base64 (Spark plan fallback)");
        }
      };
      reader.readAsDataURL(file);
    }
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading settings...</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Admin Settings</h1>
      </div>

      {message && (
        <div className={`message ${message.startsWith("Error") ? "error" : "success"}`}>
          {message}
        </div>
      )}

      <div className="settings-section">
        <h2>Payment per Head Limits</h2>
        <div className="form-row">
          <div className="form-group">
            <label>Minimum ({settings.currencySymbol})</label>
            <input
              type="number"
              min="0"
              step="0.01"
              value={settings.minPaymentPerHead}
              onChange={e => set("minPaymentPerHead", Number(e.target.value))}
            />
          </div>
          <div className="form-group">
            <label>Maximum ({settings.currencySymbol})</label>
            <input
              type="number"
              min="0"
              step="0.01"
              value={settings.maxPaymentPerHead}
              onChange={e => set("maxPaymentPerHead", Number(e.target.value))}
            />
          </div>
        </div>
      </div>

      <div className="settings-section">
        <h2>Currency Settings</h2>
        <div className="form-group">
          <label>Select Currency</label>
          <select
            value={settings.currencyCode}
            onChange={e => {
              const c = currencies.find(c => c.code === e.target.value);
              if (c) {
                setSettings(prev => ({ ...prev, currencyCode: c.code, currencySymbol: c.symbol }));
              }
            }}
          >
            {currencies.map(c => (
              <option key={c.code} value={c.code}>{c.code} ({c.symbol})</option>
            ))}
          </select>
        </div>
      </div>

      <div className="settings-section">
        <h2>Loan Interest</h2>
        <div className="form-group">
          <label>Interest Rate (%)</label>
          <input
            type="number"
            min="0"
            step="0.1"
            value={settings.loanInterestPercent}
            onChange={e => set("loanInterestPercent", Number(e.target.value))}
          />
          <span className="form-hint">Default interest rate for new loans</span>
        </div>
      </div>

      <div className="settings-section">
        <h2>Monthly Cutoff Dates</h2>
        <p className="form-hint">Payments are due on these days each month.</p>
        <div className="form-row">
          <div className="form-group">
            <label>1st Cutoff Day</label>
            <input
              type="number"
              min="1"
              max="31"
              value={settings.cutoffDay1}
              onChange={e => set("cutoffDay1", Number(e.target.value))}
            />
          </div>
          <div className="form-group">
            <label>2nd Cutoff Day</label>
            <input
              type="number"
              min="1"
              max="31"
              value={settings.cutoffDay2}
              onChange={e => set("cutoffDay2", Number(e.target.value))}
            />
          </div>
        </div>
      </div>

      <div className="settings-section">
        <h2>QR Payment Info</h2>
        <p className="form-hint">Members see this when paying contributions.</p>
        <div className="form-group">
          <label>Account Name</label>
          <input
            type="text"
            value={settings.qrAccountName}
            onChange={e => set("qrAccountName", e.target.value)}
            placeholder="e.g. LendWUs Group Fund"
          />
        </div>
        <div className="form-group">
          <label>Account Number</label>
          <input
            type="text"
            value={settings.qrAccountNumber}
            onChange={e => set("qrAccountNumber", e.target.value)}
            placeholder="e.g. 09123456789"
          />
        </div>
        <div className="form-group">
          <label>QR Code Image</label>
          {settings.qrImageUrl ? (
            <div style={{ border: "1px solid #21262d", borderRadius: 8, padding: 12, marginBottom: 8 }}>
              <img
                src={settings.qrImageUrl}
                alt="QR Code"
                style={{ maxWidth: 200, maxHeight: 200, borderRadius: 4, display: "block", marginBottom: 8 }}
              />
              <button
                type="button"
                className="btn btn-outline btn-sm"
                onClick={() => set("qrImageUrl", "")}
                style={{ color: "#ef4444", borderColor: "#ef4444" }}
              >
                Remove QR
              </button>
            </div>
          ) : (
            <label className="btn btn-outline btn-sm" style={{ cursor: "pointer", display: "inline-block" }}>
              📷 Upload QR Code Image
              <input type="file" accept="image/*" onChange={handleQRImage} style={{ display: "none" }} />
            </label>
          )}
        </div>
      </div>

      <div className="settings-section">
        <h2>APK Download</h2>
        <p className="form-hint">Configure the Android APK download link and version shown on the landing page.</p>
        <div className="form-group">
          <label>APK Download URL</label>
          <input
            type="url"
            value={settings.apkDownloadUrl}
            onChange={e => set("apkDownloadUrl", e.target.value)}
            placeholder="e.g. https://www.mediafire.com/file/..."
          />
        </div>
        <div className="form-group">
          <label>APK Version</label>
          <input
            type="text"
            value={settings.apkVersion}
            onChange={e => set("apkVersion", e.target.value)}
            placeholder="e.g. v3.1"
          />
        </div>
        <div className="form-group">
          <label>Download Count</label>
          <div style={{ padding: "10px 12px", background: "#0d1117", borderRadius: 8, color: "#22c55e", fontWeight: 700, fontSize: 18 }}>
            {settings.downloadCount ?? 0}
          </div>
          <span className="form-hint">Total APK downloads (auto-tracked)</span>
        </div>
      </div>

      <div className="settings-section">
        <h2>Contact Information</h2>
        <p className="form-hint">Shown in the footer of the landing page.</p>
        <div className="form-group">
          <label>Contact Email</label>
          <input
            type="email"
            value={settings.contactEmail}
            onChange={e => set("contactEmail", e.target.value)}
            placeholder="e.g. support@lendwus.com"
          />
        </div>
        <div className="form-group">
          <label>Contact Phone</label>
          <input
            type="tel"
            value={settings.contactPhone}
            onChange={e => set("contactPhone", e.target.value)}
            placeholder="e.g. +63 991 718 5691"
          />
        </div>
      </div>

      <div className="settings-section">
        <h2>Admin Emails</h2>
        <p className="form-hint">Users with these emails are recognized as admins on login.</p>
        <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
          <input
            type="email"
            value={newAdminEmail}
            onChange={e => setNewAdminEmail(e.target.value)}
            placeholder="admin@example.com"
            style={{ flex: 1 }}
            onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); addAdminEmail(); } }}
          />
          <button type="button" className="btn btn-primary btn-sm" onClick={addAdminEmail}>Add</button>
        </div>
        {settings.adminEmails.length === 0 ? (
          <span style={{ fontSize: 13, color: "#8b949e" }}>No admin emails configured.</span>
        ) : (
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
            {settings.adminEmails.map(email => (
              <span key={email} className="chip active-chip" style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
                {email}
                <button
                  type="button"
                  onClick={() => removeAdminEmail(email)}
                  style={{ background: "none", border: "none", color: "#ef4444", cursor: "pointer", fontSize: 14, padding: 0, lineHeight: 1 }}
                >
                  ×
                </button>
              </span>
            ))}
          </div>
        )}
      </div>

      <button
        className="btn btn-primary btn-block"
        onClick={handleSave}
        disabled={saving}
      >
        {saving ? "Saving..." : "Save Settings"}
      </button>
    </div>
  );
};

export default Settings;
