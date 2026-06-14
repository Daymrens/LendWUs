import React, { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  collection,
  query,
  getDocs,
  getDoc,
  doc,
  where,
  orderBy,
  Timestamp,
} from "firebase/firestore";
import { db } from "../../firebase";
import { downloadCSV } from "../../utils/export";

/* eslint-disable @typescript-eslint/no-explicit-any */

interface Contribution {
  id: string;
  memberId: string;
  amount: number;
  date: Timestamp;
  status: string;
  notes?: string;
  createdBy?: string;
}
interface Loan {
  id: string;
  memberId: string;
  principal: number;
  issuedDate: Timestamp;
  dueDate: Timestamp;
  interestRate: number;
  isFullyRepaid: boolean;
  status: string;
}
interface Payment {
  id: string;
  memberId: string;
  type: string;
  amount: number;
  status: string;
  requestDate: Timestamp;
  approvedDate?: Timestamp;
  notes?: string;
  receiptUrl?: string;
}

const MemberProfile: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [member, setMember] = useState<any>(null);
  const [contributions, setContributions] = useState<Contribution[]>([]);
  const [loans, setLoans] = useState<Loan[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [tab, setTab] = useState(0);
  const [selectedContrib, setSelectedContrib] = useState<Contribution | null>(null);

  useEffect(() => {
    if (!id) return;
    loadMember();
  }, [id]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadMember = async () => {
    setLoading(true);
    setError("");
    try {
      const [memSnap, contribSnap, loansSnap, paySnap] = await Promise.all([
        getDoc(doc(db, "members", id!)),
        getDocs(query(collection(db, "contributions"), where("memberId", "==", id))),
        getDocs(query(collection(db, "loans"), where("memberId", "==", id), orderBy("issuedDate", "desc"))),
        getDocs(query(collection(db, "payment_requests"), where("memberId", "==", id))),
      ]);
      if (!memSnap.exists()) { setError("Member not found"); setLoading(false); return; }
      setMember({ id: memSnap.id, ...memSnap.data() });
      setContributions(contribSnap.docs.map(d => ({ id: d.id, ...d.data() } as Contribution)));
      setLoans(loansSnap.docs.map(d => ({ id: d.id, ...d.data() } as Loan)));
      setPayments(paySnap.docs.map(d => ({ id: d.id, ...d.data() } as Payment)));
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  };

  const exportStatement = () => {
    const rows: Record<string, unknown>[] = [];
    contributions.forEach(c => {
      rows.push({ Date: c.date?.toDate?.()?.toLocaleDateString() || "", Type: "Contribution", Amount: c.amount, Status: c.status });
    });
    loans.forEach(l => {
      rows.push({ Date: l.issuedDate?.toDate?.()?.toLocaleDateString() || "", Type: "Loan Issued", Amount: l.principal, Status: l.isFullyRepaid ? "Repaid" : "Active" });
    });
    payments.forEach(p => {
      rows.push({ Date: p.requestDate?.toDate?.()?.toLocaleDateString() || "", Type: p.type === "loan" ? "Loan Repayment" : "Contribution Payment", Amount: p.amount, Status: p.status });
    });
    rows.sort((a, b) => String(a.Date).localeCompare(String(b.Date)));
    downloadCSV(rows, `statement_${member?.name || id}`);
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading profile...</p></div>;
  if (error) return <div className="admin-error"><p>{error}</p><button className="btn btn-primary" onClick={() => navigate("/admin/members")}>Back to Members</button></div>;
  if (!member) return null;

  const fmt = (n: number) => n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const totalContribs = contributions.reduce((s, c) => s + (Number(c.amount) || 0), 0);
  const totalLoans = loans.reduce((s, l) => s + (Number(l.principal) || 0), 0);
  const totalRepaid = payments.filter(p => p.type === "loan" && p.status === "approved").reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const activeLoans = loans.filter(l => !l.isFullyRepaid).length;

  return (
    <div className="admin-page">
      <div className="page-header">
        <div>
          <button className="btn btn-outline btn-sm" onClick={() => navigate("/admin/members")} style={{ marginRight: 12 }}>← Back</button>
          <h1 style={{ display: "inline" }}>{member.name}</h1>
        </div>
        <button className="btn btn-primary btn-sm" onClick={exportStatement}>Export Statement</button>
      </div>

      <div className="stat-grid" style={{ gridTemplateColumns: "repeat(4, 1fr)" }}>
        <div className="stat-card gradient"><div className="stat-label">Total Contributions</div><div className="stat-value">₱{fmt(totalContribs)}</div></div>
        <div className="stat-card"><div className="stat-label">Total Loans</div><div className="stat-value">₱{fmt(totalLoans)}</div></div>
        <div className="stat-card"><div className="stat-label">Active Loans</div><div className="stat-value">{activeLoans}</div></div>
        <div className="stat-card"><div className="stat-label">Repayments Made</div><div className="stat-value">₱{fmt(totalRepaid)}</div></div>
      </div>

      <div className="member-detail-info" style={{ background: "#161b22", border: "1px solid #21262d", borderRadius: 12, padding: 16, marginBottom: 24 }}>
        <div style={{ display: "flex", gap: 24, flexWrap: "wrap", color: "#8b949e", fontSize: 13 }}>
          <span><strong style={{ color: "#c9d1d9" }}>Balance:</strong> ₱{fmt(member.balance || 0)}</span>
          <span><strong style={{ color: "#c9d1d9" }}>Heads:</strong> {member.headsCount || 0}</span>
          <span><strong style={{ color: "#c9d1d9" }}>Per Head:</strong> ₱{fmt(member.amountPerHead || 0)}</span>
          <span><strong style={{ color: "#c9d1d9" }}>Required:</strong> ₱{fmt(member.totalRequired || 0)}</span>
          {member.linkedEmail && <span><strong style={{ color: "#c9d1d9" }}>Email:</strong> {member.linkedEmail}</span>}
          <span><strong style={{ color: "#c9d1d9" }}>Status:</strong> {(member.active ?? member.isActive) ? <span style={{ color: "#22c55e" }}>Active</span> : <span style={{ color: "#ef4444" }}>Inactive</span>}</span>
          <span><strong style={{ color: "#c9d1d9" }}>Joined:</strong> {member.joinedAt?.toDate?.()?.toLocaleDateString() || "N/A"}</span>
        </div>
      </div>

      <div className="tabs" style={{ marginBottom: 16 }}>
        {["Contributions", "Loans", "Payments"].map((t, i) => (
          <button key={t} className={`tab ${i === tab ? "active" : ""}`} onClick={() => setTab(i)}>{t}</button>
        ))}
      </div>

      {tab === 0 && (
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Date</th><th>Amount</th><th>Notes</th><th>Status</th></tr></thead>
            <tbody>
              {contributions.length === 0 ? <tr><td colSpan={4} className="empty-text">No contributions</td></tr> :
                contributions.map(c => (
                  <tr key={c.id} onClick={() => setSelectedContrib(c)} style={{ cursor: "pointer" }}>
                    <td>{c.date?.toDate?.()?.toLocaleDateString() || "N/A"}</td>
                    <td>₱{fmt(Number(c.amount) || 0)}</td>
                    <td>
                      {c.createdBy === "admin" ? <span className="chip badge-orange" style={{ fontSize: 11 }}>Admin</span> :
                       c.createdBy === "system" ? <span className="chip" style={{ fontSize: 11, background: "#1f6feb33", color: "#58a6ff", border: "1px solid #1f6feb" }}>Balance</span> :
                       c.notes || "-"}
                    </td>
                    <td><span className={`chip ${c.status === "approved" ? "active-chip" : c.status === "pending" ? "badge-orange" : "inactive-chip"}`}>{c.status || "pending"}</span></td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
      )}

      {tab === 1 && (
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Issued</th><th>Principal</th><th>Interest</th><th>Due Date</th><th>Status</th></tr></thead>
            <tbody>
              {loans.length === 0 ? <tr><td colSpan={5} className="empty-text">No loans</td></tr> :
                loans.map(l => (
                  <tr key={l.id}>
                    <td>{l.issuedDate?.toDate?.()?.toLocaleDateString() || "N/A"}</td>
                    <td>₱{fmt(Number(l.principal) || 0)}</td>
                    <td>{((Number(l.interestRate) || 0) * 100).toFixed(0)}%</td>
                    <td>{l.dueDate?.toDate?.()?.toLocaleDateString() || "N/A"}</td>
                    <td><span className={`chip ${l.isFullyRepaid ? "active-chip" : "badge-orange"}`}>{l.isFullyRepaid ? "Repaid" : "Active"}</span></td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
      )}

      {tab === 2 && (
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Date</th><th>Type</th><th>Amount</th><th>Status</th></tr></thead>
            <tbody>
              {payments.length === 0 ? <tr><td colSpan={4} className="empty-text">No payments</td></tr> :
                payments.map(p => (
                  <tr key={p.id}>
                    <td>{p.requestDate?.toDate?.()?.toLocaleDateString() || "N/A"}</td>
                    <td>{p.type === "loan" ? "Loan Repayment" : "Contribution"}</td>
                    <td>₱{fmt(Number(p.amount) || 0)}</td>
                    <td><span className={`chip ${p.status === "approved" ? "active-chip" : p.status === "pending" ? "badge-orange" : "inactive-chip"}`}>{p.status}</span></td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
      )}
      {selectedContrib && (
        <div className="modal-overlay" onClick={() => setSelectedContrib(null)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 400 }}>
            <div className="modal-header">
              <h2>Contribution Details</h2>
              <button className="btn-icon" onClick={() => setSelectedContrib(null)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>
            <div className="modal-body" style={{ padding: "0 24px 24px" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
                <div style={{
                  width: 48, height: 48, borderRadius: "50%",
                  background: selectedContrib.createdBy === "admin" ? "#f59e0b33" : "#22c55e33",
                  display: "flex", alignItems: "center", justifyContent: "center",
                }}>
                  <svg width="24" height="24" viewBox="0 0 24 24" fill={selectedContrib.createdBy === "admin" ? "#f59e0b" : "#22c55e"}>
                    {selectedContrib.createdBy === "admin"
                      ? <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                      : <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>}
                  </svg>
                </div>
                <div>
                  <div style={{ fontSize: 24, fontWeight: 700, color: "#c9d1d9" }}>
                    ₱{fmt(Number(selectedContrib.amount) || 0)}
                  </div>
                  <div style={{ fontSize: 13, color: "#8b949e" }}>
                    {selectedContrib.date?.toDate?.()?.toLocaleDateString() || "N/A"}
                  </div>
                </div>
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                <div style={{ display: "flex", fontSize: 13 }}>
                  <span style={{ width: 100, color: "#8b949e" }}>Month</span>
                  <span style={{ color: "#c9d1d9", fontWeight: 500 }}>
                    {(selectedContrib.date?.toDate?.()?.getMonth() ?? 0) + 1}/{(selectedContrib.date?.toDate?.()?.getFullYear() || "N/A")}
                  </span>
                </div>
                {selectedContrib.notes && (
                  <div style={{ display: "flex", fontSize: 13 }}>
                    <span style={{ width: 100, color: "#8b949e" }}>Notes</span>
                    <span style={{ color: "#c9d1d9", fontWeight: 500 }}>{selectedContrib.notes}</span>
                  </div>
                )}
                <div style={{ display: "flex", fontSize: 13 }}>
                  <span style={{ width: 100, color: "#8b949e" }}>Source</span>
                  <span style={{ color: "#c9d1d9", fontWeight: 500 }}>
                    {selectedContrib.createdBy === "admin" ? "Logged by Admin" :
                     selectedContrib.createdBy === "system" ? "Balance Application" : "Member Payment"}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MemberProfile;
