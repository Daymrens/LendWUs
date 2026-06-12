import React, { useEffect, useState, useMemo } from "react";
import { collection, getDocs, deleteDoc, doc, Timestamp } from "firebase/firestore";
import { db } from "../../firebase";
import { downloadCSV } from "../../utils/export";
import { backfillMissingMemberIds } from "../../utils/memberId";

const DataManagement: React.FC = () => {
  const [tab, setTab] = useState(0);
  const [contributions, setContributions] = useState<Record<string,unknown>[]>([]);
  const [loans, setLoans] = useState<Record<string,unknown>[]>([]);
  const [payments, setPayments] = useState<Record<string,unknown>[]>([]);
  const [memberMap, setMemberMap] = useState<Record<string,string>>({});
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [confirming, setConfirming] = useState<{ collection: string; id: string } | null>(null);
  const [backfilling, setBackfilling] = useState(false);
  const [backfillResult, setBackfillResult] = useState<string | null>(null);

  const tabs = ["Contributions", "Loans", "Payments"];

  useEffect(() => { loadAll(); }, []);

  const loadAll = async () => {
    setLoading(true);
    try {
      const [mSnap, cSnap, lSnap, pSnap] = await Promise.all([
        getDocs(collection(db, "members")),
        getDocs(collection(db, "contributions")),
        getDocs(collection(db, "loans")),
        getDocs(collection(db, "payment_requests")),
      ]);
      const mm: Record<string,string> = {};
      mSnap.docs.forEach(d => { mm[d.id] = d.data().name || d.id; });
      setMemberMap(mm);
      setContributions(cSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoans(lSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setPayments(pSnap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  const handleDelete = async (collectionName: string, id: string) => {
    try {
      await deleteDoc(doc(db, collectionName, id));
      setConfirming(null);
      loadAll();
    } catch (err: unknown) { alert(err instanceof Error ? err.message : "Delete failed"); }
  };

  const handleExport = (data: Record<string,unknown>[], name: string) => {
    downloadCSV(data, name);
  };

  const handleBackfill = async () => {
    setBackfilling(true);
    setBackfillResult(null);
    try {
      const count = await backfillMissingMemberIds(db);
      setBackfillResult(`Backfilled ${count} member${count !== 1 ? "s" : ""}`);
      loadAll();
    } catch (err: unknown) {
      setBackfillResult(`Failed: ${err instanceof Error ? err.message : "Unknown error"}`);
    } finally {
      setBackfilling(false);
    }
  };

  const fmtDate = (d: unknown) => {
    if (!d) return "\u2014";
    const ts = d as Timestamp;
    if (ts?.toDate) return ts.toDate().toLocaleDateString();
    return new Date(String(d)).toLocaleDateString();
  };

  const currentData = [contributions, loans, payments][tab];
  const currentName = ["contributions", "loans", "payment_requests"][tab];

  const filtered = useMemo(() => {
    if (!search.trim()) return currentData;
    const q = search.toLowerCase();
    return currentData.filter((row: Record<string,unknown>) => {
      const memberName = memberMap[row.memberId as string] || "";
      const amount = String(row.amount || row.principal || "");
      const rawStatus = row.status as string || "";
      const status = rawStatus || (row.isFullyRepaid ? "paid" : "active");
      return memberName.toLowerCase().includes(q) || amount.includes(q) || status.includes(q);
    });
  }, [currentData, search, memberMap]);

  const totalAmount = useMemo(() => {
    if (tab === 0) return filtered.reduce((s, c) => s + (Number(c.amount) || 0), 0);
    if (tab === 1) return filtered.reduce((s, l) => s + (Number(l.principal) || 0), 0);
    return filtered.reduce((s, p) => s + (Number(p.amount) || 0), 0);
  }, [filtered, tab]);

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading data...</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Data Management</h1>
        <div style={{ display: "flex", gap: 8 }}>
          <button
            className="btn btn-sm"
            onClick={handleBackfill}
            disabled={backfilling}
            style={{ background: "#f59e0b", color: "#000", border: "none", fontWeight: 700 }}
          >
            {backfilling ? "Backfilling..." : "Backfill Member IDs"}
          </button>
          <button className="btn btn-outline btn-sm" onClick={loadAll}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
            Refresh
          </button>
        </div>
      </div>

      {backfillResult && (
        <div className={`send-notif-result ${backfillResult.startsWith("Backfilled") ? "success" : "error"}`} style={{ marginBottom: 16 }}>
          {backfillResult.startsWith("Backfilled") ? "\u2705" : "\u26A0\uFE0F"} {backfillResult}
        </div>
      )}

      <div className="data-mgmt-controls">
        <div className="tabs">
          {tabs.map((t, i) => (
            <button key={t} className={`tab ${i === tab ? "active" : ""}`} onClick={() => setTab(i)}>
              {t}
              <span className="tab-count">{currentData === contributions ? contributions.length : currentData === loans ? loans.length : payments.length}</span>
            </button>
          ))}
        </div>
        <div className="data-mgmt-actions">
          <div className="data-mgmt-search">
            <svg className="data-mgmt-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input className="search-input" type="text" placeholder={`Search ${tabs[tab].toLowerCase()}...`} value={search} onChange={e => setSearch(e.target.value)} style={{ paddingLeft: 32, marginBottom: 0 }} />
          </div>
          <button className="btn btn-outline btn-sm" onClick={() => handleExport(filtered, currentName)}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            Export CSV
          </button>
        </div>
      </div>

      <div className="data-mgmt-stats">
        <div className="data-mgmt-stat">
          <span className="data-mgmt-stat-value">{filtered.length}</span>
          <span className="data-mgmt-stat-label">Records</span>
        </div>
        <div className="data-mgmt-stat">
          <span className="data-mgmt-stat-value">
            {filtered.length !== currentData.length && (
              <span style={{ color: "#8b949e", fontSize: 13, fontWeight: 400 }}>{currentData.length} total</span>
            )}
          </span>
          <span className="data-mgmt-stat-label" />
        </div>
        <div className="data-mgmt-stat">
          <span className="data-mgmt-stat-value" style={{ color: tab === 1 ? "#f59e0b" : "#22c55e" }}>
            ₱{totalAmount.toLocaleString()}
          </span>
          <span className="data-mgmt-stat-label">Total {tab === 0 ? "Contributions" : tab === 1 ? "Principal" : "Amount"}</span>
        </div>
      </div>

      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              {tab === 0 && <><th>Member</th><th>Amount</th><th>Date</th><th>Period</th><th style={{width:50}} /></>}
              {tab === 1 && <><th>Member</th><th>Principal</th><th>Rate</th><th>Issued</th><th>Due</th><th>Status</th><th style={{width:50}} /></>}
              {tab === 2 && <><th>Member</th><th>Type</th><th>Amount</th><th>Status</th><th>Date</th><th style={{width:50}} /></>}
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr><td colSpan={tab === 0 ? 5 : tab === 1 ? 7 : 6} style={{ textAlign: "center", color: "#8b949e", padding: 40 }}>
                {search ? "No matching records" : "No records found"}
              </td></tr>
            ) : filtered.map((row: Record<string,unknown>) => (
              <tr key={row.id as string}>
                {tab === 0 && (
                  <>
                    <td><div className="data-mgmt-member">{memberMap[row.memberId as string] || (row.memberId as string)}</div></td>
                    <td className="text-success fw-bold">₱{(Number(row.amount) || 0).toLocaleString()}</td>
                    <td className="text-muted">{fmtDate(row.date)}</td>
                    <td><span className="period-badge">{String(row.month ?? "")}/{String(row.year ?? "")}</span></td>
                    <td><button className="btn-icon danger" onClick={() => setConfirming({ collection: "contributions", id: row.id as string })} title="Delete"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button></td>
                  </>
                )}
                {tab === 1 && (
                  <>
                    <td><div className="data-mgmt-member">{memberMap[row.memberId as string] || (row.memberId as string)}</div></td>
                    <td className="text-pending fw-bold">₱{(Number(row.principal) || 0).toLocaleString()}</td>
                    <td className="text-muted">{((Number(row.interestRate) || 0) * 100).toFixed(0)}%</td>
                    <td className="text-muted">{fmtDate(row.issuedDate)}</td>
                    <td className="text-muted">{fmtDate(row.dueDate)}</td>
                    <td>{row.isFullyRepaid ? <span className="badge badge-blue">Paid</span> : <span className="badge badge-orange">Active</span>}</td>
                    <td><button className="btn-icon danger" onClick={() => setConfirming({ collection: "loans", id: row.id as string })} title="Delete"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button></td>
                  </>
                )}
                {tab === 2 && (
                  <>
                    <td><div className="data-mgmt-member">{memberMap[row.memberId as string] || (row.memberId as string)}</div></td>
                    <td>{row.type === "loan" ? "Loan Repayment" : "Contribution"}</td>
                    <td className="fw-bold">₱{(Number(row.amount) || 0).toLocaleString()}</td>
                    <td><span className={`badge ${row.status === "approved" ? "badge-blue" : row.status === "rejected" ? "badge-inactive" : "badge-orange"}`}>{row.status as string}</span></td>
                    <td className="text-muted">{fmtDate(row.requestDate)}</td>
                    <td><button className="btn-icon danger" onClick={() => setConfirming({ collection: "payment_requests", id: row.id as string })} title="Delete"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button></td>
                  </>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {confirming && (
        <div className="modal-overlay" onClick={() => setConfirming(null)}>
          <div className="modal-card" onClick={e => e.stopPropagation()} style={{ maxWidth: 400 }}>
            <div className="modal-header">
              <h3>Confirm Delete</h3>
            </div>
            <div className="modal-body" style={{ color: "#c9d1d9", fontSize: 14, lineHeight: 1.5 }}>
              <div style={{ textAlign: "center", fontSize: 40, marginBottom: 12 }}>\u26A0\uFE0F</div>
              <p>Are you sure you want to delete this record? This action cannot be undone.</p>
            </div>
            <div className="modal-actions" style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
              <button className="btn btn-outline btn-sm" onClick={() => setConfirming(null)}>Cancel</button>
              <button className="btn btn-sm" onClick={() => handleDelete(confirming.collection, confirming.id)} style={{ background: "#ef4444", color: "#fff", border: "none" }}>Delete</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DataManagement;
