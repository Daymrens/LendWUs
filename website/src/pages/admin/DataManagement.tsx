import React, { useEffect, useState } from "react";
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

  const tabs = ["Contributions", "Loans", "Payments"];

  useEffect(() => { loadAll(); }, []);

  const loadAll = async () => {
    setLoading(true);
    try {
      const [mSnap, cSnap, lSnap, pSnap] = await Promise.all([
        getDocs(collection(db,"members")),
        getDocs(collection(db,"contributions")),
        getDocs(collection(db,"loans")),
        getDocs(collection(db,"payment_requests")),
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
    if (!window.confirm("Delete this record? This cannot be undone.")) return;
    try {
      await deleteDoc(doc(db, collectionName, id));
      loadAll();
    } catch (err: unknown) { alert(err instanceof Error ? err.message : "Delete failed"); }
  };

  const handleExport = (data: Record<string,unknown>[], name: string) => {
    downloadCSV(data, name);
  };

  const handleBackfill = async () => {
    if (!window.confirm("This will generate formatted IDs (LWS000000) for all members missing them, ordered by join date. Proceed?")) return;
    try {
      setLoading(true);
      const count = await backfillMissingMemberIds(db);
      alert(`Successfully backfilled ${count} members.`);
      loadAll();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Backfill failed");
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading data...</p></div>;

  const fmtDate = (d: unknown) => {
    if (!d) return "—";
    const ts = d as Timestamp;
    if (ts?.toDate) return ts.toDate().toLocaleDateString();
    return new Date(String(d)).toLocaleDateString();
  };

  return (
    <div className="admin-page">
      <div className="page-header" style={{ flexDirection: "column", alignItems: "flex-start", gap: 16 }}>
        <h1>Data Management</h1>
        <div style={{ display: "flex", gap: 12, width: "100%", justifyContent: "space-between" }}>
          <div style={{ display: "flex", gap: 12 }}>
            <button 
              className="btn btn-primary btn-sm" 
              onClick={handleBackfill}
              style={{ backgroundColor: "#f59e0b", color: "#000" }}
            >
              Backfill Member IDs
            </button>
            <button className="btn btn-outline btn-sm" onClick={loadAll}>Refresh</button>
          </div>
        </div>
      </div>

      <div className="tabs" style={{ marginBottom: 16 }}>
        {tabs.map((t,i) => (
          <button key={t} className={`tab ${i===tab?"active":""}`} onClick={()=>setTab(i)}>{t}</button>
        ))}
      </div>

      {tab === 0 && (
        <>
          <div style={{ display:"flex", gap:8, marginBottom:12, alignItems:"center", justifyContent:"space-between" }}>
            <span style={{ color:"#8b949e", fontSize:13 }}>{contributions.length} records</span>
            <button className="btn btn-outline btn-sm" onClick={() => handleExport(contributions,"contributions")}>Export CSV</button>
          </div>
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>Member</th><th>Amount</th><th>Date</th><th>Month</th><th>Year</th><th>Actions</th></tr></thead>
              <tbody>
                {contributions.map(c => (
                  <tr key={c.id as string}>
                    <td>{memberMap[c.memberId as string] || (c.memberId as string)}</td>
                    <td className="text-success">₱{(Number(c.amount)||0).toLocaleString()}</td>
                    <td>{fmtDate(c.date)}</td>
                    <td>{String(c.month ?? "")}</td>
                    <td>{String(c.year ?? "")}</td>
                    <td><button className="btn-icon danger" onClick={()=>handleDelete("contributions",c.id as string)} title="Delete"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {tab === 1 && (
        <>
          <div style={{ display:"flex", gap:8, marginBottom:12, alignItems:"center", justifyContent:"space-between" }}>
            <span style={{ color:"#8b949e", fontSize:13 }}>{loans.length} records</span>
            <button className="btn btn-outline btn-sm" onClick={() => handleExport(loans,"loans")}>Export CSV</button>
          </div>
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>Member</th><th>Principal</th><th>Interest</th><th>Issued</th><th>Due</th><th>Status</th><th>Actions</th></tr></thead>
              <tbody>
                {loans.map(l => (
                  <tr key={l.id as string}>
                    <td>{memberMap[l.memberId as string] || (l.memberId as string)}</td>
                    <td className="text-pending">₱{(Number(l.principal)||0).toLocaleString()}</td>
                    <td>{String(l.interestRate ?? "")}%</td>
                    <td>{fmtDate(l.issuedDate)}</td>
                    <td>{fmtDate(l.dueDate)}</td>
                    <td>{l.isFullyRepaid ? <span className="badge badge-blue">Paid</span> : <span className="badge badge-orange">Active</span>}</td>
                    <td><button className="btn-icon danger" onClick={()=>handleDelete("loans",l.id as string)} title="Delete"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {tab === 2 && (
        <>
          <div style={{ display:"flex", gap:8, marginBottom:12, alignItems:"center", justifyContent:"space-between" }}>
            <span style={{ color:"#8b949e", fontSize:13 }}>{payments.length} records</span>
            <button className="btn btn-outline btn-sm" onClick={() => handleExport(payments,"payment_requests")}>Export CSV</button>
          </div>
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>Member</th><th>Type</th><th>Amount</th><th>Status</th><th>Date</th><th>Actions</th></tr></thead>
              <tbody>
                {payments.map(p => (
                  <tr key={p.id as string}>
                    <td>{memberMap[p.memberId as string] || (p.memberId as string)}</td>
                    <td>{p.type === "loan" ? "Loan Repayment" : "Contribution"}</td>
                    <td>₱{(Number(p.amount)||0).toLocaleString()}</td>
                    <td><span className={`badge ${p.status==="approved"?"badge-blue":p.status==="rejected"?"badge-inactive":"badge-orange"}`}>{p.status as string}</span></td>
                    <td>{fmtDate(p.requestDate)}</td>
                    <td><button className="btn-icon danger" onClick={()=>handleDelete("payment_requests",p.id as string)} title="Delete"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
};

export default DataManagement;
