import React, { useEffect, useState, useRef } from "react";
import {
  collection,
  query,
  where,
  onSnapshot,
  Timestamp,
  doc,
  getDoc,
  getDocs,
  limit,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";
import RepaymentModal from "./modals/RepaymentModal";

interface Loan {
  id: string;
  memberId: string;
  principal: number;
  interestRate: number;
  dueDate: Timestamp;
  issuedDate: Timestamp;
  isFullyRepaid: boolean;
  remainingBalance?: number;
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

const Loans: React.FC = () => {
  const { user } = useMemberAuth();
  const memberId = user?.memberId;
  const [loans, setLoans] = useState<Loan[]>([]);
  const [loading, setLoading] = useState(true);
  const [showRepaymentModal, setShowRepaymentModal] = useState(false);
  const [repayLoan, setRepayLoan] = useState<Loan | null>(null);
  const [showRepaid, setShowRepaid] = useState(false);
  const [memberDocId, setMemberDocId] = useState("");
  const [viewReceipt, setViewReceipt] = useState<LoanReceipt | null>(null);
  const shownReceiptLoans = useRef<Set<string>>(new Set());

  useEffect(() => {
    if (!memberId) return;
    getDoc(doc(db, "members", memberId)).then(snap => {
      if (snap.exists()) setMemberDocId(snap.id);
    });
  }, [memberId]);

  useEffect(() => {
    if (!memberId) return;
    const unsub = onSnapshot(
      query(collection(db, "loans"), where("memberId", "==", memberId)),
      async (snap) => {
        const loanList = snap.docs.map(d => ({ id: d.id, ...d.data() } as Loan));
        const withBalances = await Promise.all(loanList.map(async (loan) => {
          if (loan.isFullyRepaid) return { ...loan, remainingBalance: 0 };
          const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
          const repayQ = query(collection(db, "repayments"), where("loanId", "==", loan.id));
          const repaySnap = await getDocs(repayQ);
          let repaid = 0;
          repaySnap.docs.forEach(d => { repaid += Number(d.data().amountPaid) || 0; });
          return { ...loan, remainingBalance: Math.max(0, totalDue - repaid) };
        }));
        setLoans(withBalances);
        setLoading(false);

        // Auto-pop receipt for newly approved loans
        const newLoan = withBalances.find(l => !l.isFullyRepaid && !shownReceiptLoans.current.has(l.id));
        if (newLoan) {
          try {
            const rSnap = await getDocs(query(
              collection(db, "loan_receipts"),
              where("loanId", "==", newLoan.id),
              where("copyFor", "==", "borrower"),
              limit(1),
            ));
            if (!rSnap.empty) {
              shownReceiptLoans.current.add(newLoan.id);
              setViewReceipt({ id: rSnap.docs[0].id, ...rSnap.docs[0].data() } as LoanReceipt);
            }
          } catch { /* silently ignore receipt query errors */ }
        }
      },
    );
    return unsub;
  }, [memberId]);

  const handleViewReceipt = async (loan: Loan) => {
    try {
      const receiptSnap = await getDocs(query(
        collection(db, "loan_receipts"),
        where("loanId", "==", loan.id),
        where("copyFor", "==", "borrower"),
        limit(1),
      ));
      if (receiptSnap.empty) {
        alert("No receipt available yet. Please ask an admin to generate one.");
        return;
      }
      setViewReceipt({ id: receiptSnap.docs[0].id, ...receiptSnap.docs[0].data() } as LoanReceipt);
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to load receipt");
    }
  };

  const now = new Date();
  const activeLoans = loans.filter(l => !l.isFullyRepaid);
  const repaidLoans = loans.filter(l => l.isFullyRepaid);
  const totalPrincipal = activeLoans.reduce((sum, l) => sum + l.principal, 0);
  const overdueCount = activeLoans.filter(l => {
    const dueDate = l.dueDate?.toDate?.();
    return dueDate && dueDate < now;
  }).length;

  if (loading) return (
    <div className="admin-page">
      <div className="page-header"><h1>My Loans</h1></div>
      <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>
    </div>
  );

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>My Loans</h1>
        <span className="chip active-chip">{activeLoans.length} active</span>
      </div>

      {/* Stats summary */}
      <div className="mini-stats" style={{ marginBottom: 24 }}>
        <div className="stat-card">
          <div className="stat-label">Active Loans</div>
          <div className="stat-value">{activeLoans.length}</div>
        </div>
        <div className="stat-card gradient">
          <div className="stat-label">Total Principal</div>
          <div className="stat-value">₱{formatCurrency(totalPrincipal)}</div>
        </div>
        <div className="stat-card" style={{ borderColor: overdueCount > 0 ? "rgba(239,68,68,0.3)" : undefined }}>
          <div className="stat-label">Overdue</div>
          <div className="stat-value" style={{ color: overdueCount > 0 ? "#ef4444" : "#22c55e" }}>
            {overdueCount === 0 ? "None" : overdueCount}
          </div>
        </div>
      </div>

      {/* Active Loans */}
      <div className="section">
        <h2>🏦 Active Loans</h2>
        {activeLoans.length === 0 ? (
          <div className="chart-card" style={{ textAlign: "center", padding: 32 }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>✅</div>
            <p style={{ color: "#22c55e", fontWeight: 600, fontSize: 16, margin: 0 }}>No active loans</p>
            <p style={{ color: "#8b949e", fontSize: 13, marginTop: 8 }}>
              You have no outstanding loans. You can request one from the Dashboard.
            </p>
          </div>
        ) : (
          <div className="activity-list">
            {activeLoans.map(loan => {
              const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
              const remaining = loan.remainingBalance ?? totalDue;
              const progress = totalDue > 0 ? (totalDue - remaining) / totalDue : 0;
              const dueDate = loan.dueDate?.toDate?.();
              const isOverdue = dueDate && dueDate < now;
              const daysOverdue = dueDate ? Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24)) : 0;

              return (
                <div key={loan.id} className="stat-card" style={{ marginBottom: 12 }}>
                  <div className="approval-top" style={{ marginBottom: 8 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <span style={{ fontSize: 18 }}>🏦</span>
                      <div>
                        <strong>Loan #{loan.id.slice(0, 5)}</strong>
                        <span style={{ marginLeft: 8, fontSize: 12, color: "#8b949e" }}>
                          {(loan.interestRate * 100).toFixed(0)}% interest
                        </span>
                      </div>
                    </div>
                    <span style={{ fontSize: 18, fontWeight: 700, color: isOverdue ? "#ef4444" : "#f59e0b" }}>
                      ₱{formatCurrency(remaining)}
                    </span>
                  </div>
                  <div className="approval-details" style={{ marginBottom: 8 }}>
                    <span>Principal: ₱{formatCurrency(loan.principal)}</span>
                    <span>Due: {formatDate(loan.dueDate)}</span>
                    <span>Issued: {formatDate(loan.issuedDate)}</span>
                  </div>
                  <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
                    <div style={{ flex: 1, height: 8, background: "#1c2128", borderRadius: 4, overflow: "hidden" }}>
                      <div style={{
                        width: `${progress * 100}%`,
                        height: "100%",
                        background: isOverdue ? "#ef4444" : "#22c55e",
                        borderRadius: 4,
                        transition: "width 0.3s ease",
                      }} />
                    </div>
                    <span style={{ fontSize: 11, color: "#8b949e", minWidth: 32, textAlign: "right" }}>
                      {(progress * 100).toFixed(0)}%
                    </span>
                  </div>
                  <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                    {isOverdue && (
                      <span className="chip" style={{ background: "rgba(239,68,68,0.15)", color: "#ef4444" }}>
                        ⚠ {daysOverdue} days overdue
                      </span>
                    )}
                    <span className="chip" style={{ background: "rgba(34,197,94,0.1)", color: "#22c55e", marginLeft: "auto" }}>
                      ₱{formatCurrency(remaining)} remaining
                    </span>
                  </div>
                  <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
                    <button
                      className="btn btn-outline btn-sm"
                      style={{ flex: 1, borderColor: "rgba(59,130,246,0.3)", color: "#3b82f6" }}
                      onClick={() => handleViewReceipt(loan)}
                    >
                      📄 View Receipt
                    </button>
                    <button
                      className="btn btn-warning btn-sm"
                      style={{ flex: 1 }}
                      onClick={() => { setRepayLoan(loan); setShowRepaymentModal(true); }}
                    >
                      Make a Repayment
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Repaid Loans */}
      {repaidLoans.length > 0 && (
        <div className="section" style={{ marginTop: 0 }}>
          <button
            className="stat-card"
            style={{
              width: "100%",
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              cursor: "pointer",
              border: "1px solid rgba(34,197,94,0.15)",
              background: "rgba(34,197,94,0.04)",
            }}
            onClick={() => setShowRepaid(!showRepaid)}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <span style={{ fontSize: 18 }}>✅</span>
              <div style={{ textAlign: "left" }}>
                <div style={{ fontWeight: 600, color: "#22c55e", fontSize: 14 }}>
                  Repaid Loans
                </div>
                <div style={{ fontSize: 11, color: "#8b949e", marginTop: 2 }}>
                  {repaidLoans.length} loan{repaidLoans.length > 1 ? "s" : ""} fully paid
                </div>
              </div>
            </div>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              style={{
                transform: showRepaid ? "rotate(180deg)" : "none",
                transition: "transform 0.2s",
                color: "#8b949e",
              }}
            >
              <polyline points="6 9 12 15 18 9"/>
            </svg>
          </button>
          {showRepaid && (
            <div className="activity-list" style={{ marginTop: 8 }}>
              {repaidLoans.map(loan => (
                <div key={loan.id} className="stat-card" style={{ marginBottom: 8, opacity: 0.85 }}>
                  <div className="approval-top" style={{ marginBottom: 4 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <span style={{ fontSize: 16 }}>✅</span>
                      <div>
                        <strong>Loan #{loan.id.slice(0, 5)}</strong>
                        <span style={{ marginLeft: 8, fontSize: 12, color: "#8b949e" }}>
                          {(loan.interestRate * 100).toFixed(0)}% interest
                        </span>
                      </div>
                    </div>
                    <span className="chip" style={{ background: "rgba(34,197,94,0.15)", color: "#22c55e", fontWeight: 600 }}>
                      FULLY PAID
                    </span>
                  </div>
                  <div className="approval-details">
                    <span>Principal: ₱{formatCurrency(loan.principal)}</span>
                    <span>Due: {formatDate(loan.dueDate)}</span>
                    <span>Paid: {formatDate(loan.issuedDate)}</span>
                  </div>
                  <button
                    className="btn btn-outline btn-sm"
                    style={{ width: "100%", marginTop: 8, borderColor: "rgba(59,130,246,0.3)", color: "#3b82f6" }}
                    onClick={() => handleViewReceipt(loan)}
                  >
                    📄 View Receipt
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

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

              <div className="receipt-divider" />

              <div className="receipt-number-row">
                <span className="receipt-number-label">Receipt No.</span>
                <span className="receipt-number-value">{viewReceipt.receiptNumber}</span>
              </div>

              <div className="receipt-amount-box">
                <div className="receipt-amount">₱{formatCurrency(viewReceipt.totalAmountDue)}</div>
                <div className="receipt-amount-label">Total Amount Due</div>
              </div>

              <div className="receipt-divider" />

              <table className="receipt-table">
                <tbody>
                  <tr><td className="receipt-label">Principal</td><td className="receipt-value">₱{formatCurrency(viewReceipt.principal)}</td></tr>
                  <tr><td className="receipt-label">Interest Rate</td><td className="receipt-value">{(viewReceipt.interestRate * 100).toFixed(1)}%</td></tr>
                  <tr><td className="receipt-label">Interest Amount</td><td className="receipt-value">₱{formatCurrency(viewReceipt.interestAmount)}</td></tr>
                  <tr className="receipt-spacer"><td colSpan={2}></td></tr>
                  <tr><td className="receipt-label">Issue Date</td><td className="receipt-value">{formatDate(viewReceipt.issuedDate)}</td></tr>
                  <tr><td className="receipt-label">Due Date</td><td className="receipt-value">{formatDate(viewReceipt.dueDate)}</td></tr>
                  <tr><td className="receipt-label">Status</td><td className="receipt-value">{viewReceipt.status.toUpperCase()}</td></tr>
                  <tr><td className="receipt-label">Generated</td><td className="receipt-value">{formatDate(viewReceipt.generatedAt)}</td></tr>
                </tbody>
              </table>

              <div className="receipt-divider" />

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

      {showRepaymentModal && repayLoan && (
        <RepaymentModal
          memberDocId={memberDocId}
          loanId={repayLoan.id}
          principal={repayLoan.principal}
          interestRate={repayLoan.interestRate}
          remainingBalance={repayLoan.remainingBalance ?? (repayLoan.principal + (repayLoan.principal * (repayLoan.interestRate || 0)))}
          onClose={() => { setShowRepaymentModal(false); setRepayLoan(null); }}
        />
      )}
    </div>
  );
};

export default Loans;
