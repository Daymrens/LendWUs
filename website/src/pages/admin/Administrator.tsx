import React, { useState, useEffect } from "react";
import { collection, query, getDocs, addDoc, updateDoc, deleteDoc, doc, Timestamp, where, orderBy } from "firebase/firestore";
import { signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut } from "firebase/auth";
import { auth, db } from "../../firebase";

const ADMIN_EMAIL = "admin001@lendwus.app";
const ADMIN_PASS = "admin001";

interface Group {
  id: string;
  groupCode: string;
  name: string;
  adminEmails: string[];
  treasurerEmails: string[];
  loanInterestPercent: number;
  currencySymbol: string;
  currencyCode: string;
  isActive: boolean;
  minPaymentPerHead: number;
  maxPaymentPerHead: number;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}

const emptyForm = (): Omit<Group, "id" | "createdAt" | "updatedAt"> => ({
  groupCode: "",
  name: "",
  adminEmails: [],
  treasurerEmails: [],
  loanInterestPercent: 10,
  currencySymbol: "₱",
  currencyCode: "PHP",
  isActive: true,
  minPaymentPerHead: 100,
  maxPaymentPerHead: 5000,
});

const Administrator: React.FC = () => {
  const [loggedIn, setLoggedIn] = useState(false);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loginError, setLoginError] = useState("");

  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editing, setEditing] = useState<Group | null>(null);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [emailInput, setEmailInput] = useState("");
  const [treasurerInput, setTreasurerInput] = useState("");

  useEffect(() => {
    if (!loggedIn) return;
    loadGroups();
  }, [loggedIn]);

  const loadGroups = async () => {
    setLoading(true);
    setError("");
    try {
      const q = query(collection(db, "groups"), orderBy("createdAt", "desc"));
      const snap = await getDocs(q);
      setGroups(snap.docs.map(d => ({ id: d.id, ...d.data() } as Group)));
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load groups");
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError("");
    try {
      const email = username.includes("@") ? username : `${username}@lendwus.app`;
      if (email !== ADMIN_EMAIL) {
        setLoginError("Invalid credentials");
        return;
      }
      try {
        await signInWithEmailAndPassword(auth, email, password);
      } catch (signInErr: unknown) {
        // Auto-create the admin account on first login
        if ((signInErr as { code?: string }).code === "auth/user-not-found") {
          await createUserWithEmailAndPassword(auth, email, password);
        } else {
          throw signInErr;
        }
      }
      setLoggedIn(true);
    } catch (err: unknown) {
      setLoginError(err instanceof Error ? err.message : "Invalid credentials");
    }
  };

  const handleLogout = async () => {
    await signOut(auth);
    setLoggedIn(false);
    setUsername("");
    setPassword("");
    setGroups([]);
    setEditing(null);
    setCreating(false);
  };

  const openCreate = () => {
    setForm(emptyForm());
    setEmailInput("");
    setTreasurerInput("");
    setCreating(true);
    setEditing(null);
  };

  const openEdit = (g: Group) => {
    setForm({
      groupCode: g.groupCode,
      name: g.name,
      adminEmails: [...g.adminEmails],
      treasurerEmails: [...g.treasurerEmails],
      loanInterestPercent: g.loanInterestPercent,
      currencySymbol: g.currencySymbol,
      currencyCode: g.currencyCode,
      isActive: g.isActive,
      minPaymentPerHead: g.minPaymentPerHead,
      maxPaymentPerHead: g.maxPaymentPerHead,
    });
    setEmailInput("");
    setTreasurerInput("");
    setEditing(g);
    setCreating(false);
  };

  const closeForm = () => {
    setEditing(null);
    setCreating(false);
    setForm(emptyForm());
    setEmailInput("");
    setTreasurerInput("");
  };

  const addAdminEmail = () => {
    const e = emailInput.trim().toLowerCase();
    if (e && !form.adminEmails.includes(e)) {
      setForm({ ...form, adminEmails: [...form.adminEmails, e] });
    }
    setEmailInput("");
  };

  const removeAdminEmail = (e: string) => {
    setForm({ ...form, adminEmails: form.adminEmails.filter(a => a !== e) });
  };

  const addTreasurerEmail = () => {
    const e = treasurerInput.trim().toLowerCase();
    if (e && !form.treasurerEmails.includes(e)) {
      setForm({ ...form, treasurerEmails: [...form.treasurerEmails, e] });
    }
    setTreasurerInput("");
  };

  const removeTreasurerEmail = (e: string) => {
    setForm({ ...form, treasurerEmails: form.treasurerEmails.filter(a => a !== e) });
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.groupCode.trim() || !form.name.trim()) {
      alert("Group code and name are required");
      return;
    }
    setSaving(true);
    try {
      const now = Timestamp.now();
      if (editing) {
        await updateDoc(doc(db, "groups", editing.id), {
          ...form,
          updatedAt: now,
        });
      } else {
        const q = query(collection(db, "groups"), where("groupCode", "==", form.groupCode.trim()));
        const existing = await getDocs(q);
        if (!existing.empty) {
          alert(`Group code "${form.groupCode}" already exists`);
          setSaving(false);
          return;
        }
        await addDoc(collection(db, "groups"), {
          ...form,
          createdAt: now,
          updatedAt: now,
        });
      }
      closeForm();
      await loadGroups();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to save");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (g: Group) => {
    if (!window.confirm(`Delete group "${g.name}" (${g.groupCode})? This cannot be undone.`)) return;
    try {
      await deleteDoc(doc(db, "groups", g.id));
      await loadGroups();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to delete");
    }
  };

  const handleToggleActive = async (g: Group) => {
    try {
      await updateDoc(doc(db, "groups", g.id), {
        isActive: !g.isActive,
        updatedAt: Timestamp.now(),
      });
      await loadGroups();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to update");
    }
  };

  if (!loggedIn) {
    return (
      <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", background: "#0d1117", padding: 20 }}>
        <div style={{ background: "#161b22", borderRadius: 16, padding: 40, width: "100%", maxWidth: 400, border: "1px solid #21262d" }}>
          <div style={{ textAlign: "center", marginBottom: 28 }}>
            <div style={{ fontSize: 28, fontWeight: 700, color: "#f0f6fc" }}>LendWUs</div>
            <div style={{ fontSize: 13, color: "#8b949e", marginTop: 4 }}>Group Administrator</div>
          </div>
          <form onSubmit={handleLogin}>
            <div style={{ marginBottom: 16 }}>
              <label style={{ display: "block", fontSize: 12, color: "#8b949e", marginBottom: 6, fontWeight: 600 }}>Username</label>
              <input
                type="text"
                value={username}
                onChange={e => setUsername(e.target.value)}
                style={{ width: "100%", padding: "10px 14px", borderRadius: 10, border: "1px solid #30363d", background: "#0d1117", color: "#f0f6fc", fontSize: 14, outline: "none" }}
                placeholder="admin001"
                autoFocus
              />
            </div>
            <div style={{ marginBottom: 20 }}>
              <label style={{ display: "block", fontSize: 12, color: "#8b949e", marginBottom: 6, fontWeight: 600 }}>Password</label>
              <input
                type="password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                style={{ width: "100%", padding: "10px 14px", borderRadius: 10, border: "1px solid #30363d", background: "#0d1117", color: "#f0f6fc", fontSize: 14, outline: "none" }}
                placeholder="••••••••"
              />
            </div>
            {loginError && <div style={{ color: "#ef4444", fontSize: 13, marginBottom: 12, textAlign: "center" }}>{loginError}</div>}
            <button type="submit" style={{ width: "100%", padding: "12px 0", borderRadius: 12, border: "none", background: "#22c55e", color: "white", fontSize: 15, fontWeight: 600, cursor: "pointer" }}>
              Sign In
            </button>
          </form>
          <div style={{ textAlign: "center", marginTop: 16 }}>
            <a href="/" style={{ color: "#8b949e", fontSize: 12, textDecoration: "none" }}>← Back to Home</a>
          </div>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="admin-loading"><div className="spinner" /><p>Loading groups...</p></div>
    );
  }

  return (
    <div className="admin-page" style={{ padding: "24px 32px", maxWidth: 1200, margin: "0 auto" }}>
      <div className="page-header" style={{ marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 24, margin: 0 }}>Group Administrator</h1>
          <p style={{ color: "#8b949e", fontSize: 13, marginTop: 4 }}>Manage all fund groups across the platform</p>
        </div>
        <div style={{ display: "flex", gap: 10 }}>
          <button className="btn btn-primary" onClick={openCreate}>+ New Group</button>
          <button className="btn btn-outline" onClick={handleLogout}>Sign Out</button>
        </div>
      </div>

      {error && <div className="admin-banner error" style={{ marginBottom: 16 }}>{error}</div>}

      {/* Group list */}
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {groups.length === 0 ? (
          <div style={{ textAlign: "center", padding: 60, color: "#8b949e" }}>
            <p style={{ fontSize: 18, marginBottom: 8 }}>No groups yet</p>
            <p style={{ fontSize: 13 }}>Click "+ New Group" to create the first group.</p>
          </div>
        ) : groups.map(g => (
          <div key={g.id} style={{
            background: "#161b22", borderRadius: 14, border: "1px solid #21262d",
            padding: "16px 20px", display: "flex", alignItems: "center", gap: 16,
            opacity: g.isActive ? 1 : 0.5,
          }}>
            <div style={{ width: 42, height: 42, borderRadius: 10, background: g.isActive ? "#1a4d2e" : "#21262d", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 18, fontWeight: 700, color: "#22c55e", flexShrink: 0 }}>
              {g.groupCode.charAt(0)}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
                <span style={{ fontSize: 15, fontWeight: 600, color: "#f0f6fc" }}>{g.name}</span>
                <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 6, background: "#1c2333", color: "#8b949e", fontFamily: "monospace" }}>{g.groupCode}</span>
                {!g.isActive && <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 6, background: "#ef444420", color: "#ef4444" }}>Inactive</span>}
              </div>
              <div style={{ fontSize: 12, color: "#8b949e", marginTop: 4, display: "flex", gap: 16, flexWrap: "wrap" }}>
                <span>{g.adminEmails.length} admin{g.adminEmails.length !== 1 ? "s" : ""}</span>
                <span>{g.treasurerEmails.length} treasurer{g.treasurerEmails.length !== 1 ? "s" : ""}</span>
                <span>{g.currencySymbol}{g.currencyCode}</span>
                <span>{g.loanInterestPercent}% interest</span>
              </div>
            </div>
            <div style={{ display: "flex", gap: 6, flexShrink: 0 }}>
              <button className="btn btn-outline btn-sm" onClick={() => openEdit(g)}>Edit</button>
              <button
                className={`btn btn-outline btn-sm`}
                style={{ borderColor: g.isActive ? "#f59e0b" : "#22c55e", color: g.isActive ? "#f59e0b" : "#22c55e" }}
                onClick={() => handleToggleActive(g)}
              >
                {g.isActive ? "Deactivate" : "Activate"}
              </button>
              <button className="btn btn-outline btn-sm" style={{ borderColor: "#ef4444", color: "#ef4444" }} onClick={() => handleDelete(g)}>Delete</button>
            </div>
          </div>
        ))}
      </div>

      {/* Create/Edit modal */}
      {(creating || editing) && (
        <div className="modal-overlay" onClick={closeForm}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 560, maxHeight: "90vh", overflowY: "auto" }}>
            <div className="modal-header">
              <h2>{editing ? "Edit Group" : "New Group"}</h2>
              <button className="btn-icon" onClick={closeForm}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
              </button>
            </div>
            <form onSubmit={handleSave}>
              <div className="form-group">
                <label>Group Name</label>
                <input type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="e.g. LendWUs Family Fund" required />
              </div>
              <div className="form-group">
                <label>Group Code</label>
                <input
                  type="text"
                  value={form.groupCode}
                  onChange={e => setForm({ ...form, groupCode: e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, "") })}
                  placeholder="e.g. LENDWUS"
                  disabled={!!editing}
                  maxLength={20}
                  required
                  style={{ fontFamily: "monospace", letterSpacing: 2 }}
                />
                <small style={{ color: "#8b949e", fontSize: 11 }}>Used for member self-onboarding. Cannot be changed after creation.</small>
              </div>
              <div className="form-row" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div className="form-group">
                  <label>Currency Symbol</label>
                  <input type="text" value={form.currencySymbol} onChange={e => setForm({ ...form, currencySymbol: e.target.value })} placeholder="₱" maxLength={5} />
                </div>
                <div className="form-group">
                  <label>Currency Code</label>
                  <input type="text" value={form.currencyCode} onChange={e => setForm({ ...form, currencyCode: e.target.value.toUpperCase() })} placeholder="PHP" maxLength={3} />
                </div>
              </div>
              <div className="form-row" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div className="form-group">
                  <label>Loan Interest (%)</label>
                  <input type="number" min="0" max="100" step="0.1" value={form.loanInterestPercent} onChange={e => setForm({ ...form, loanInterestPercent: parseFloat(e.target.value) || 0 })} />
                </div>
                <div className="form-group">
                  <label>Status</label>
                  <select value={form.isActive ? "active" : "inactive"} onChange={e => setForm({ ...form, isActive: e.target.value === "active" })}>
                    <option value="active">Active</option>
                    <option value="inactive">Inactive</option>
                  </select>
                </div>
              </div>
              <div className="form-row" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div className="form-group">
                  <label>Min Payment Per Head</label>
                  <input type="number" min="0" step="0.01" value={form.minPaymentPerHead} onChange={e => setForm({ ...form, minPaymentPerHead: parseFloat(e.target.value) || 0 })} />
                </div>
                <div className="form-group">
                  <label>Max Payment Per Head</label>
                  <input type="number" min="0" step="0.01" value={form.maxPaymentPerHead} onChange={e => setForm({ ...form, maxPaymentPerHead: parseFloat(e.target.value) || 0 })} />
                </div>
              </div>
              <div className="form-group">
                <label>Admin Emails</label>
                <div style={{ display: "flex", gap: 6, marginBottom: 6 }}>
                  <input
                    type="email"
                    value={emailInput}
                    onChange={e => setEmailInput(e.target.value)}
                    onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); addAdminEmail(); } }}
                    placeholder="Type email and press Enter"
                    style={{ flex: 1 }}
                  />
                  <button type="button" className="btn btn-outline btn-sm" onClick={addAdminEmail}>Add</button>
                </div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                  {form.adminEmails.map(e => (
                    <span key={e} style={{ display: "inline-flex", alignItems: "center", gap: 4, background: "#1c2333", borderRadius: 8, padding: "4px 10px", fontSize: 12, color: "#f0f6fc" }}>
                      {e}
                      <button type="button" onClick={() => removeAdminEmail(e)} style={{ background: "none", border: "none", color: "#ef4444", cursor: "pointer", padding: 0, fontSize: 14, lineHeight: 1 }}>×</button>
                    </span>
                  ))}
                </div>
              </div>
              <div className="form-group">
                <label>Treasurer Emails</label>
                <div style={{ display: "flex", gap: 6, marginBottom: 6 }}>
                  <input
                    type="email"
                    value={treasurerInput}
                    onChange={e => setTreasurerInput(e.target.value)}
                    onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); addTreasurerEmail(); } }}
                    placeholder="Type email and press Enter"
                    style={{ flex: 1 }}
                  />
                  <button type="button" className="btn btn-outline btn-sm" onClick={addTreasurerEmail}>Add</button>
                </div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                  {form.treasurerEmails.map(e => (
                    <span key={e} style={{ display: "inline-flex", alignItems: "center", gap: 4, background: "#1c2333", borderRadius: 8, padding: "4px 10px", fontSize: 12, color: "#f0f6fc" }}>
                      {e}
                      <button type="button" onClick={() => removeTreasurerEmail(e)} style={{ background: "none", border: "none", color: "#ef4444", cursor: "pointer", padding: 0, fontSize: 14, lineHeight: 1 }}>×</button>
                    </span>
                  ))}
                </div>
              </div>
              <div className="modal-actions">
                <button type="button" className="btn btn-outline" onClick={closeForm}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? "Saving..." : (editing ? "Update Group" : "Create Group")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default Administrator;
