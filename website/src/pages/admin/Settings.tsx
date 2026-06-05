import React, { useEffect, useState } from "react";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { db } from "../../firebase";

interface AppSettings {
  minPaymentPerHead: number;
  maxPaymentPerHead: number;
  loanInterestPercent: number;
  currencySymbol: string;
  currencyCode: string;
  cutoffDay1: number;
  cutoffDay2: number;
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

const Settings: React.FC = () => {
  const [settings, setSettings] = useState<AppSettings>({
    minPaymentPerHead: 150,
    maxPaymentPerHead: 1000,
    loanInterestPercent: 10,
    currencySymbol: "\u20B1",
    currencyCode: "PHP",
    cutoffDay1: 13,
    cutoffDay2: 28,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    const load = async () => {
      try {
        const snap = await getDoc(doc(db, "settings", "app"));
        if (snap.exists()) {
          setSettings(snap.data() as AppSettings);
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
      await setDoc(doc(db, "settings", "app"), settings);
      setMessage("Settings saved successfully");
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to save";
      setMessage("Error: " + msg);
    } finally {
      setSaving(false);
    }
  };

  const set = (key: keyof AppSettings, value: string | number) => {
    setSettings(prev => ({ ...prev, [key]: value }));
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
