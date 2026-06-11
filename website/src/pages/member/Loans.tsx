import React, { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  onSnapshot,
  Timestamp,
  doc,
  getDoc,
  getDocs,
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
      },
    );
    return unsub;
  }, [memberId]);

  const now = new Date();
  const activeLoans = loans.filter(l => !l.isFullyRepaid);
  const repaidLoans = loans.filter(l => l.isFullyRepaid);

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

      {/* Active Loans */}
      <div className="section">
        <h2>Active Loans</h2>
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
                <div key={loan.id} className="approval-card" style={{ marginBottom: 12 }}>
                  <div className="approval-top">
                    <div>
                      <strong>Loan #{loan.id.slice(0, 5)}</strong>
                      <span style={{ marginLeft: 8, fontSize: 12, color: "#8b949e" }}>
                        {(loan.interestRate * 100).toFixed(0)}% interest
                      </span>
                    </div>
                    <span className="approval-amount" style={{ color: isOverdue ? "#ef4444" : "#f59e0b" }}>
                      ₱{formatCurrency(remaining)}
                    </span>
                  </div>
                  {isOverdue && (
                    <span className="chip" style={{ background: "rgba(239,68,68,0.15)", color: "#ef4444", marginBottom: 8, display: "inline-block" }}>
                      {daysOverdue} days overdue
                    </span>
                  )}
                  <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
                    <div style={{ flex: 1, height: 6, background: "#1c2128", borderRadius: 3, overflow: "hidden" }}>
                      <div style={{ width: `${progress * 100}%`, height: "100%", background: isOverdue ? "#ef4444" : "#f59e0b", borderRadius: 3 }} />
                    </div>
                    <span style={{ fontSize: 11, color: "#8b949e" }}>{(progress * 100).toFixed(0)}%</span>
                  </div>
                  <div className="approval-details">
                    <span>Principal: ₱{formatCurrency(loan.principal)}</span>
                    <span>Due: {formatDate(loan.dueDate)}</span>
                    <span>Issued: {formatDate(loan.issuedDate)}</span>
                  </div>
                  <button
                    className="btn btn-warning btn-sm"
                    style={{ width: "100%", marginTop: 8 }}
                    onClick={() => { setRepayLoan(loan); setShowRepaymentModal(true); }}
                  >
                    Repay Loan
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Repaid Loans */}
      {repaidLoans.length > 0 && (
        <div className="section">
          <button
            className="btn btn-outline btn-sm"
            style={{ width: "100%", justifyContent: "space-between", display: "flex", alignItems: "center" }}
            onClick={() => setShowRepaid(!showRepaid)}
          >
            <span>Repaid Loans ({repaidLoans.length})</span>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ transform: showRepaid ? "rotate(180deg)" : "none", transition: "transform 0.2s" }}>
              <polyline points="6 9 12 15 18 9"/>
            </svg>
          </button>
          {showRepaid && (
            <div className="activity-list" style={{ marginTop: 12 }}>
              {repaidLoans.map(loan => (
                <div key={loan.id} className="approval-card" style={{ marginBottom: 8, opacity: 0.8 }}>
                  <div className="approval-top">
                    <div>
                      <strong>Loan #{loan.id.slice(0, 5)}</strong>
                      <span style={{ marginLeft: 8, fontSize: 12, color: "#8b949e" }}>
                        {(loan.interestRate * 100).toFixed(0)}% interest
                      </span>
                    </div>
                    <span className="chip" style={{ background: "rgba(34,197,94,0.15)", color: "#22c55e" }}>
                      PAID
                    </span>
                  </div>
                  <div className="approval-details">
                    <span>Principal: ₱{formatCurrency(loan.principal)}</span>
                    <span>Due: {formatDate(loan.dueDate)}</span>
                    <span>Paid: {formatDate(loan.issuedDate)}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
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