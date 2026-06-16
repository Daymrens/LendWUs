import React, { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  getDocs,
  getDoc,
  doc,
  updateDoc,
  Timestamp,
  writeBatch,
  onSnapshot,
  limit,
} from "firebase/firestore";
import { db } from "../../firebase";

interface Loan {
  id: string;
  memberId: string;
  memberName?: string;
  principal: number;
  interestRate: number;
  dueDate: Timestamp;
  issuedDate: Timestamp;
  isFullyRepaid: boolean;
  remainingBalance?: number;
  totalRepaid?: number;
  hasReceipt?: boolean;
}

interface LoanReceipt {
  id: string;
  loanId: string;
  receiptNumber: string;
  memberName: string;
  principal: number;
  interestRate: number;
  interestAmount: number;
  totalAmountDue: number;
  issuedDate: Timestamp;
  dueDate: Timestamp;
  status: string;
  copyFor: string;
  generatedAt: Timestamp;
}

const formatCurrency = (n: number) =>
  n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatDate = (ts: Timestamp | undefined) => {
  if (!ts?.toDate) return "N/A";
  return ts.toDate().toLocaleDateString();
};

const AdminLoans: React.FC = () => {
  const [loans, setLoans] = useState<Loan[]>([]);
  const [members, setMembers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState(0);
  const [search, setSearch] = useState("");
  const [repayLoan, setRepayLoan] = useState<Loan | null>(null);
  const [repayAmount, setRepayAmount] = useState("");
  const [submittingRepay, setSubmittingRepay] = useState(false);
  const [viewReceipt, setViewReceipt] = useState<{ receipt: LoanReceipt; loan: Loan } | null>(null);
  const [generatingAll, setGeneratingAll] = useState(false);

  const tabs = ["All", "Active", "Overdue", "Repaid"];

  useEffect(() => {
    getDocs(collection(db, "members")).then(snap => {
      const map: Record<string, string> = {};
      snap.docs.forEach(d => { const data = d.data(); map[d.id] = data.name || d.id; });
      setMembers(map);
    });
  }, []);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, "loans"), async (snap) => {
      const loanList = snap.docs.map(d => ({ id: d.id, ...d.data() } as Loan));
      const receiptLoanIds = new Set<string>();
      const receiptSnap = await getDocs(collection(db, "loan_receipts"));
      receiptSnap.docs.forEach(d => receiptLoanIds.add(d.data().loanId));

      const withBalances = await Promise.all(loanList.map(async (loan) => {
        if (loan.isFullyRepaid) return { ...loan, remainingBalance: 0, totalRepaid: 0, hasReceipt: receiptLoanIds.has(loan.id) };
        const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
        const repayQ = query(collection(db, "repayments"), where("loanId", "==", loan.id));
        const repaySnap = await getDocs(repayQ);
        let repaid = 0;
        repaySnap.docs.forEach(d => { repaid += Number(d.data().amountPaid) || 0; });
        return {
          ...loan,
          remainingBalance: Math.max(0, totalDue - repaid),
          totalRepaid: repaid,
          memberName: members[loan.memberId] || loan.memberId,
          hasReceipt: receiptLoanIds.has(loan.id),
        };
      }));
      setLoans(withBalances);
      setLoading(false);
    });
    return unsub;
  }, [members]);

  const now = new Date();

  const filtered = loans.filter(loan => {
    const name = (loan.memberName || members[loan.memberId] || "").toLowerCase();
    const matchesSearch = name.includes(search.toLowerCase());
    const dueDate = loan.dueDate?.toDate?.();
    const isOverdue = dueDate && dueDate < now && !loan.isFullyRepaid;

    if (tab === 1) return matchesSearch && !loan.isFullyRepaid;
    if (tab === 2) return matchesSearch && isOverdue;
    if (tab === 3) return matchesSearch && loan.isFullyRepaid;
    return matchesSearch;
  });

  const activeLoans = loans.filter(l => !l.isFullyRepaid);
  const overdueLoans = activeLoans.filter(l => {
    const d = l.dueDate?.toDate?.();
    return d && d < now;
  });
  const totalOutstanding = activeLoans.reduce((s, l) => s + (l.remainingBalance ?? l.principal), 0);
  const totalPrincipal = activeLoans.reduce((s, l) => s + l.principal, 0);
  const totalInterestEarned = loans.reduce((s, l) => {
    const repaid = l.totalRepaid ?? 0;
    return s + Math.max(0, repaid - l.principal);
  }, 0);

  const handleRepayment = async () => {
    if (!repayLoan) return;
    const amt = parseFloat(repayAmount);
    if (!Number.isFinite(amt) || amt <= 0) { alert("Amount must be greater than 0."); return; }
    if (amt > (repayLoan.remainingBalance ?? 0)) {
      if (!window.confirm(`Amount exceeds remaining balance. Overpayment of ₱${formatCurrency(amt - (repayLoan.remainingBalance ?? 0))} will be credited. Continue?`)) return;
    }
    setSubmittingRepay(true);
    try {
      const batch = writeBatch(db);
      const repayRef = doc(collection(db, "repayments"));
      batch.set(repayRef, {
        loanId: repayLoan.id,
        amountPaid: amt,
        date: Timestamp.now(),
      });
      const newRemaining = (repayLoan.remainingBalance ?? 0) - amt;
      if (newRemaining <= 0) {
        batch.update(doc(db, "loans", repayLoan.id), { isFullyRepaid: true });
      }
      await batch.commit();
      setRepayLoan(null);
      setRepayAmount("");
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to record repayment");
    } finally { setSubmittingRepay(false); }
  };

  const handleGenerateReceipts = async (loan: Loan) => {
    try {
      const memberSnap = await getDoc(doc(db, "members", loan.memberId));
      const memberName = memberSnap.exists() ? (memberSnap.data().name || loan.memberId) : loan.memberId;
      const now = Timestamp.now();
      const receiptNumber = `LR-${now.toDate().getFullYear()}${String(now.toDate().getMonth() + 1).padStart(2, "0")}-${String(now.toDate().getTime() % 100000).padStart(5, "0")}`;
      const interestAmount = loan.principal * (loan.interestRate || 0);
      const totalAmountDue = loan.principal + interestAmount;

      const batch = writeBatch(db);
      batch.set(doc(collection(db, "loan_receipts")), {
        loanId: loan.id,
        receiptNumber,
        memberId: loan.memberId,
        memberName,
        principal: loan.principal,
        interestRate: loan.interestRate || 0,
        interestAmount,
        totalAmountDue,
        issuedDate: loan.issuedDate,
        dueDate: loan.dueDate,
        status: loan.isFullyRepaid ? "repaid" : "active",
        copyFor: "admin",
        generatedAt: now,
      });
      batch.set(doc(collection(db, "loan_receipts")), {
        loanId: loan.id,
        receiptNumber,
        memberId: loan.memberId,
        memberName,
        principal: loan.principal,
        interestRate: loan.interestRate || 0,
        interestAmount,
        totalAmountDue,
        issuedDate: loan.issuedDate,
        dueDate: loan.dueDate,
        status: loan.isFullyRepaid ? "repaid" : "active",
        copyFor: "borrower",
        generatedAt: now,
      });
      await batch.commit();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to generate receipt");
    }
  };

  const handleViewReceipt = async (loan: Loan) => {
    try {
      const receiptSnap = await getDocs(query(
        collection(db, "loan_receipts"),
        where("loanId", "==", loan.id),
        where("copyFor", "==", "admin"),
        limit(1),
      ));
      if (receiptSnap.empty) {
        await handleGenerateReceipts(loan);
        const retry = await getDocs(query(
          collection(db, "loan_receipts"),
          where("loanId", "==", loan.id),
          where("copyFor", "==", "admin"),
          limit(1),
        ));
        if (retry.empty) { alert("Failed to generate receipt"); return; }
        setViewReceipt({ receipt: { id: retry.docs[0].id, ...retry.docs[0].data() } as LoanReceipt, loan });
      } else {
        setViewReceipt({ receipt: { id: receiptSnap.docs[0].id, ...receiptSnap.docs[0].data() } as LoanReceipt, loan });
      }
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to load receipt");
    }
  };

  const handleGenerateAllMissing = async () => {
    if (!window.confirm(`Generate receipts for ${loans.filter(l => !l.hasReceipt).length} loans without receipts?`)) return;
    setGeneratingAll(true);
    let count = 0;
    for (const loan of loans) {
      if (loan.hasReceipt) continue;
      try {
        const memberSnap = await getDoc(doc(db, "members", loan.memberId));
        const memberName = memberSnap.exists() ? (memberSnap.data().name || loan.memberId) : loan.memberId;
        const now = Timestamp.now();
        const receiptNumber = `LR-${now.toDate().getFullYear()}${String(now.toDate().getMonth() + 1).padStart(2, "0")}-${String(now.toDate().getTime() % 100000).padStart(5, "0")}`;
        const interestAmount = loan.principal * (loan.interestRate || 0);
        const totalAmountDue = loan.principal + interestAmount;

        const batch = writeBatch(db);
        batch.set(doc(collection(db, "loan_receipts")), {
          loanId: loan.id, receiptNumber, memberId: loan.memberId, memberName,
          principal: loan.principal, interestRate: loan.interestRate || 0,
          interestAmount, totalAmountDue,
          issuedDate: loan.issuedDate, dueDate: loan.dueDate,
          status: loan.isFullyRepaid ? "repaid" : "active",
          copyFor: "admin", generatedAt: now,
        });
        batch.set(doc(collection(db, "loan_receipts")), {
          loanId: loan.id, receiptNumber, memberId: loan.memberId, memberName,
          principal: loan.principal, interestRate: loan.interestRate || 0,
          interestAmount, totalAmountDue,
          issuedDate: loan.issuedDate, dueDate: loan.dueDate,
          status: loan.isFullyRepaid ? "repaid" : "active",
          copyFor: "borrower", generatedAt: now,
        });
        await batch.commit();
        count++;
      } catch { /* skip failed */ }
    }
    setGeneratingAll(false);
    alert(`Generated ${count} receipt${count !== 1 ? "s" : ""} for existing loans.`);
  };

  const handleMarkRepaid = async (loanId: string) => {
    if (!window.confirm("Mark this loan as fully repaid? This should only be done if all payments are settled.")) return;
    try {
      await updateDoc(doc(db, "loans", loanId), { isFullyRepaid: true });
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to update loan");
    }
  };

  if (loading) return (
    <div className="admin-page">
      <div className="page-header"><h1>Loan Management</h1></div>
      <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>
    </div>
  );

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Loan Management</h1>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <button
            className="btn btn-outline btn-sm"
            onClick={handleGenerateAllMissing}
            disabled={generatingAll}
            title="Generate receipts for existing loans"
          >
            {generatingAll ? "Generating..." : "📄 Generate Receipts"}
          </button>
          <span className="chip" style={{ background: "rgba(34,197,94,0.15)", color: "#22c55e", fontWeight: 600 }}>
            {activeLoans.length} active
          </span>
          <span className="chip" style={{ background: "rgba(239,68,68,0.15)", color: "#ef4444", fontWeight: 600 }}>
            {overdueLoans.length} overdue
          </span>
        </div>
      </div>

      {/* Stats */}
      <div className="stat-grid" style={{ marginBottom: 24 }}>
        <div className="stat-card gradient">
          <div className="stat-label">Total Outstanding</div>
          <div className="stat-value">₱{formatCurrency(totalOutstanding)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Active Loans</div>
          <div className="stat-value">{activeLoans.length}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Total Principal</div>
          <div className="stat-value">₱{formatCurrency(totalPrincipal)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Interest Earned</div>
          <div className="stat-value" style={{ color: "#22c55e" }}>₱{formatCurrency(totalInterestEarned)}</div>
        </div>
      </div>

      {/* Toolbar */}
      <div className="members-toolbar">
        <input
          type="text"
          placeholder="Search by member name..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="search-input"
        />
        <div className="tabs">
          {tabs.map((t, i) => (
            <button key={t} className={`tab ${tab === i ? "active" : ""}`} onClick={() => setTab(i)}>{t}</button>
          ))}
        </div>
      </div>

      {/* Loan list */}
      <div className="members-list">
        {filtered.length === 0 ? (
          <div className="empty-text">No loans found</div>
        ) : (
          filtered.map(loan => {
            const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
            const remaining = loan.remainingBalance ?? totalDue;
            const repaid = loan.totalRepaid ?? 0;
            const progress = totalDue > 0 ? repaid / totalDue : 0;
            const dueDate = loan.dueDate?.toDate?.();
            const isOverdue = dueDate && dueDate < now && !loan.isFullyRepaid;
            const daysOverdue = dueDate ? Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24)) : 0;
            const memberName = loan.memberName || members[loan.memberId] || "Unknown";

            return (
              <div key={loan.id} className="member-card">
                <div className="member-info" style={{ flex: 1 }}>
                  <div className="approval-top" style={{ marginBottom: 6 }}>
                    <div className="member-name">{memberName}</div>
                    <span style={{ fontSize: 16, fontWeight: 700, color: loan.isFullyRepaid ? "#22c55e" : isOverdue ? "#ef4444" : "#f59e0b" }}>
                      ₱{formatCurrency(loan.isFullyRepaid ? 0 : remaining)}
                    </span>
                  </div>
                  <div className="member-details">
                    <span>Principal: ₱{formatCurrency(loan.principal)}</span>
                    <span>Rate: {(loan.interestRate * 100).toFixed(1)}%</span>
                    <span>Due: {formatDate(loan.dueDate)}</span>
                    <span>Issued: {formatDate(loan.issuedDate)}</span>
                  </div>

                  {!loan.isFullyRepaid && (
                    <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 6 }}>
                      <div style={{ flex: 1, height: 6, background: "#1c2128", borderRadius: 3, overflow: "hidden" }}>
                        <div style={{
                          width: `${progress * 100}%`,
                          height: "100%",
                          background: isOverdue ? "#ef4444" : "#22c55e",
                          borderRadius: 3,
                          transition: "width 0.3s ease",
                        }} />
                      </div>
                      <span style={{ fontSize: 11, color: "#8b949e", minWidth: 28, textAlign: "right" }}>
                        {(progress * 100).toFixed(0)}%
                      </span>
                    </div>
                  )}

                  <div style={{ display: "flex", gap: 6, marginTop: 8, flexWrap: "wrap" }}>
                    {isOverdue && (
                      <span className="chip" style={{ background: "rgba(239,68,68,0.15)", color: "#ef4444" }}>
                        ⚠ {daysOverdue} day{daysOverdue !== 1 ? "s" : ""} overdue
                      </span>
                    )}
                    {loan.isFullyRepaid && (
                      <span className="chip" style={{ background: "rgba(34,197,94,0.15)", color: "#22c55e" }}>
                        ✅ Fully Paid
                      </span>
                    )}
                    {!loan.isFullyRepaid && (
                      <>
                        <span className="chip" style={{ background: "rgba(245,158,11,0.15)", color: "#f59e0b" }}>
                          ₱{formatCurrency(remaining)} remaining
                        </span>
                        <span className="chip" style={{ background: "rgba(59,130,246,0.15)", color: "#3b82f6" }}>
                          ₱{formatCurrency(repaid)} repaid
                        </span>
                      </>
                    )}
                  </div>

                  <div className="member-actions" style={{ marginTop: 10 }}>
                    <button
                      className="btn btn-outline btn-sm"
                      style={{ borderColor: "rgba(59,130,246,0.3)", color: "#3b82f6" }}
                      onClick={() => handleViewReceipt(loan)}
                    >
                      {loan.hasReceipt ? "📄 Receipt" : "📄 Generate Receipt"}
                    </button>
                    {!loan.isFullyRepaid && (
                      <>
                        <button
                          className="btn btn-warning btn-sm"
                          onClick={() => { setRepayLoan(loan); setRepayAmount(String(remaining)); }}
                        >
                          Record Repayment
                        </button>
                        <button
                          className="btn btn-outline btn-sm"
                          style={{ borderColor: "rgba(34,197,94,0.3)", color: "#22c55e" }}
                          onClick={() => handleMarkRepaid(loan.id)}
                        >
                          Mark Fully Paid
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Receipt Modal */}
      {viewReceipt && (
        <div className="modal-overlay" onClick={() => setViewReceipt(null)}>
          <div className="modal receipt-modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 520 }}>
            <div className="modal-header no-print">
              <h2>Loan Receipt</h2>
              <button className="btn-icon" onClick={() => setViewReceipt(null)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>

            <div className="receipt-print-area">
              {/* Logo */}
              <div style={{ textAlign: "center", marginBottom: 16 }}>
                <div className="receipt-logo">
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ marginBottom: 4 }}>
                    <rect x="2" y="5" width="20" height="14" rx="2"/>
                    <line x1="2" y1="10" x2="22" y2="10"/>
                    <circle cx="12" cy="15" r="1"/>
                  </svg>
                  <span className="receipt-logo-text">Lend<span>WUs</span></span>
                </div>
                <div className="receipt-subtitle">Group Sinking Fund — Official Loan Receipt</div>
              </div>

              {/* Divider */}
              <div className="receipt-divider" />

              {/* Receipt Number */}
              <div className="receipt-number-row">
                <span className="receipt-number-label">Receipt No.</span>
                <span className="receipt-number-value">{viewReceipt.receipt.receiptNumber}</span>
              </div>

              {/* Amount */}
              <div className="receipt-amount-box">
                <div className="receipt-amount">₱{formatCurrency(viewReceipt.receipt.totalAmountDue)}</div>
                <div className="receipt-amount-label">Total Amount Due</div>
              </div>

              <div className="receipt-divider" />

              {/* Details */}
              <table className="receipt-table">
                <tbody>
                  <tr><td className="receipt-label">Borrower</td><td className="receipt-value">{viewReceipt.receipt.memberName}</td></tr>
                  <tr><td className="receipt-label">Principal</td><td className="receipt-value">₱{formatCurrency(viewReceipt.receipt.principal)}</td></tr>
                  <tr><td className="receipt-label">Interest Rate</td><td className="receipt-value">{(viewReceipt.receipt.interestRate * 100).toFixed(1)}%</td></tr>
                  <tr><td className="receipt-label">Interest Amount</td><td className="receipt-value">₱{formatCurrency(viewReceipt.receipt.interestAmount)}</td></tr>
                  <tr className="receipt-spacer"><td colSpan={2}></td></tr>
                  <tr><td className="receipt-label">Issue Date</td><td className="receipt-value">{formatDate(viewReceipt.receipt.issuedDate)}</td></tr>
                  <tr><td className="receipt-label">Due Date</td><td className="receipt-value">{formatDate(viewReceipt.receipt.dueDate)}</td></tr>
                  <tr><td className="receipt-label">Status</td><td className="receipt-value">{viewReceipt.loan.isFullyRepaid ? "FULLY PAID" : "ACTIVE"}</td></tr>
                  <tr><td className="receipt-label">Copy</td><td className="receipt-value">Admin Record</td></tr>
                  <tr><td className="receipt-label">Generated</td><td className="receipt-value">{formatDate(viewReceipt.receipt.generatedAt)}</td></tr>
                </tbody>
              </table>

              <div className="receipt-divider" />

              {/* Footer */}
              <div className="receipt-footer">
                <p>This is a computer-generated receipt. No signature required.</p>
                <p className="receipt-thankyou">Thank you for being a part of LendWUs!</p>
              </div>
            </div>

            <div className="modal-actions no-print">
              <button className="btn btn-outline" onClick={() => setViewReceipt(null)}>Close</button>
              <button className="btn btn-primary" onClick={() => window.print()}>🖨️ Print</button>
            </div>
          </div>
        </div>
      )}

      {/* Repayment Modal */}
      {repayLoan && (
        <div className="modal-overlay" onClick={() => { setRepayLoan(null); setRepayAmount(""); }}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Record Repayment</h2>
              <button className="btn-icon" onClick={() => { setRepayLoan(null); setRepayAmount(""); }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>

            <div style={{
              background: "linear-gradient(135deg, rgba(245,158,11,0.15), rgba(245,158,11,0.05))",
              border: "1px solid rgba(245,158,11,0.3)",
              borderRadius: 12, padding: 16, marginBottom: 16,
            }}>
              <div style={{ fontSize: 12, color: "#8b949e", marginBottom: 4 }}>
                {repayLoan.memberName || members[repayLoan.memberId] || "Unknown"} — {formatDate(repayLoan.dueDate)}
              </div>
              <div style={{ fontSize: 24, fontWeight: 800, color: "#f59e0b" }}>
                ₱{formatCurrency(repayLoan.remainingBalance ?? 0)}
              </div>
              <div style={{ marginTop: 4, fontSize: 12, color: "#8b949e" }}>
                Remaining balance • Principal: ₱{formatCurrency(repayLoan.principal)}
              </div>
            </div>

            <div className="form-group">
              <label>Payment Amount (₱)</label>
              <input
                type="number"
                min="0"
                step="0.01"
                value={repayAmount}
                onChange={e => setRepayAmount(e.target.value)}
                autoFocus
              />
            </div>

            <div className="modal-actions">
              <button className="btn btn-outline" onClick={() => { setRepayLoan(null); setRepayAmount(""); }}>Cancel</button>
              <button
                className="btn btn-primary"
                disabled={submittingRepay || !repayAmount || parseFloat(repayAmount) <= 0}
                onClick={handleRepayment}
              >
                {submittingRepay ? "Recording..." : "Record Payment"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminLoans;
