import React, { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  Timestamp,
  doc,
  getDoc,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";
import { useNavigate } from "react-router-dom";
import PaymentModal from "./modals/PaymentModal";
import LoanRequestModal from "./modals/LoanRequestModal";
import HeadChangeModal from "./modals/HeadChangeModal";
import RepaymentModal from "./modals/RepaymentModal";

interface Contribution {
  id: string;
  amount: number;
  date: Timestamp;
  month: number;
  year: number;
  memberId: string;
}

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

interface PaymentRequest {
  id: string;
  memberId: string;
  amount: number;
  status: string;
  type: string;
  requestDate: Timestamp;
}

interface MemberData {
  id: string;
  name: string;
  headsCount: number;
  amountPerHead: number;
  totalRequired: number;
  balance: number;
  memberId: string;
}

const formatCurrency = (n: number) =>
  n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const Dashboard: React.FC = () => {
  const navigate = useNavigate();
  const { user } = useMemberAuth();
  const memberId = user?.memberId;

  const [member, setMember] = useState<MemberData | null>(null);
  const [memberDocId, setMemberDocId] = useState<string>("");
  const [contributions, setContributions] = useState<Contribution[]>([]);
  const [loans, setLoans] = useState<Loan[]>([]);
  const [paymentRequests, setPaymentRequests] = useState<PaymentRequest[]>([]);
  const [repaymentsData, setRepaymentsData] = useState<Array<{id:string; loanId:string; amountPaid:number; memberId:string}>>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [paymentModalDefaultAdvance, setPaymentModalDefaultAdvance] = useState(false);
  const [showLoanModal, setShowLoanModal] = useState(false);
  const [showHeadModal, setShowHeadModal] = useState(false);
  const [showRepaymentModal, setShowRepaymentModal] = useState(false);
  const [showTrackDialog, setShowTrackDialog] = useState(false);
  const [repayLoan, setRepayLoan] = useState<Loan | null>(null);

  const [cutoffDay1, setCutoffDay1] = useState(13);
  const [cutoffDay2, setCutoffDay2] = useState(28);

  useEffect(() => {
    getDoc(doc(db, "app_settings", "fund_settings")).then(snap => {
      if (snap.exists()) {
        const d = snap.data();
        if (d.cutoffDay1) setCutoffDay1(d.cutoffDay1);
        if (d.cutoffDay2) setCutoffDay2(d.cutoffDay2);
      }
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (!memberId) return;
    const unsubs: Array<() => void> = [];

    console.log("[Dashboard] fetching member doc:", memberId);
    unsubs.push(onSnapshot(
      doc(db, "members", memberId),
      (snap) => {
        if (snap.exists()) {
          const data = snap.data() as Record<string, unknown>;
          console.log("[Dashboard] member doc exists, id:", snap.id, "memberId field:", data.memberId);
          setMember({ id: snap.id, ...snap.data() } as MemberData);
          setMemberDocId(snap.id);
        } else {
          console.error("[Dashboard] member doc NOT FOUND for:", memberId);
        }
        setLoading(false);
      },
      (err) => { console.error("[Dashboard] member doc error:", err); setError(err.message); setLoading(false); }
    ));

    return () => unsubs.forEach(u => u());
  }, [memberId]);

  useEffect(() => {
    if (!member?.id) return;
    console.log("[Dashboard] memberId for queries:", member.id);
    const unsubs: Array<() => void> = [];

    unsubs.push(onSnapshot(
      query(collection(db, "contributions"), where("memberId", "==", member.id), orderBy("date", "desc")),
      (snap) => { console.log("[Dashboard] contributions count:", snap.docs.length); setContributions(snap.docs.map(d => ({ id: d.id, ...d.data() } as Contribution))); },
      (err) => { console.error("[Dashboard] contributions error:", err); }
    ));

    unsubs.push(onSnapshot(
      query(collection(db, "loans"), where("memberId", "==", member.id)),
      (snap) => { setLoans(snap.docs.map(d => ({ id: d.id, ...d.data() } as Loan))); },
      (err) => { console.error("[Dashboard] loans error:", err); }
    ));

    unsubs.push(onSnapshot(
      query(collection(db, "payment_requests"), where("memberId", "==", member.id), orderBy("requestDate", "desc")),
      (snap) => { setPaymentRequests(snap.docs.map(d => ({ id: d.id, ...d.data() } as PaymentRequest))); },
      (err) => { console.error("[Dashboard] payment_requests error:", err); }
    ));

    unsubs.push(onSnapshot(
      query(collection(db, "repayments"), where("memberId", "==", member.id)),
      (snap) => { setRepaymentsData(snap.docs.map(d => ({ id: d.id, ...(d.data() as Record<string,unknown>) } as any))); },
      (err) => { console.error("[Dashboard] repayments error:", err); }
    ));

    if (user?.uid) {
      unsubs.push(onSnapshot(
        query(collection(db, "notifications"), where("userId", "==", user.uid), where("read", "==", false)),
        (snap) => { setUnreadCount(snap.docs.length); }
      ));
    }

    return () => unsubs.forEach(u => u());
  }, [member?.id, user?.uid]);

  const now = new Date();
  const totalContributions = contributions.reduce((s, c) => s + (Number(c.amount) || 0), 0);
  const activeLoans = loans.filter(l => !l.isFullyRepaid);
  const pendingCount = paymentRequests.filter(p => p.status === "pending").length;
  const totalPending = pendingCount + 0;

  const thisMonth = contributions.filter(c => {
    const d = c.date?.toDate?.();
    return d && d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
  });
  const totalThisMonth = thisMonth.reduce((s, c) => s + (Number(c.amount) || 0), 0);
  const totalHeadsCount = member?.headsCount || 1;
  const perCutoffAmount = ((member?.amountPerHead ?? 0) > 0
    ? member!.amountPerHead! * totalHeadsCount
    : member?.totalRequired ?? 0);
  const fullMonthlyRequired = perCutoffAmount * 2;
  const progress = fullMonthlyRequired > 0 ? Math.min(totalThisMonth / fullMonthlyRequired, 1) : 0;

  const loanRepaymentMap: Record<string, number> = {};
  repaymentsData.forEach((r) => {
    if (r.loanId) loanRepaymentMap[r.loanId] = (loanRepaymentMap[r.loanId] || 0) + (Number(r.amountPaid) || 0);
  });
  const totalInterestEarned = loans.reduce((s, l) => {
    const repaid = loanRepaymentMap[l.id] || 0;
    const interest = repaid - (Number(l.principal) || 0);
    return s + (interest > 0 ? interest : 0);
  }, 0);
  const perHeadShare = totalHeadsCount > 0 ? totalInterestEarned / totalHeadsCount : 0;

  // Cutoff calculation
  const today = now.getDate();
  const cutoffs = [cutoffDay1, cutoffDay2].sort((a, b) => a - b);
  let nextCutoff = cutoffs.find(c => c >= today);
  if (!nextCutoff) nextCutoff = cutoffs[0] + (new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate());
  let daysUntilNext = nextCutoff - today;
  if (daysUntilNext < 0) daysUntilNext += new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

  let cutoffLabel: string;
  let cutoffColor: string;
  if (daysUntilNext <= 0) { cutoffLabel = "Due today"; cutoffColor = "#ef4444"; }
  else if (daysUntilNext <= 3) { cutoffLabel = `${daysUntilNext} days to cutoff`; cutoffColor = "#f59e0b"; }
  else if (daysUntilNext <= 7) { cutoffLabel = `${daysUntilNext} days to cutoff`; cutoffColor = "#22c55e"; }
  else { cutoffLabel = `Cutoff in ${daysUntilNext} days`; cutoffColor = "#8b949e"; }

  if (loading) return (
    <div className="admin-page">
      <div className="page-header"><h1>Welcome</h1></div>
      <div className="section">
        <div className="chart-card">
          <div className="skeleton" style={{ width: "40%", height: 14, marginBottom: 16, borderRadius: 4 }} />
          <div className="skeleton" style={{ width: "30%", height: 32, marginBottom: 12, borderRadius: 4 }} />
          <div className="skeleton" style={{ width: "100%", height: 6, borderRadius: 3 }} />
        </div>
      </div>
      <div className="mini-stats">
        {[1,2,3,4].map(i => (
          <div key={i} className="mini-stat" style={{ border: "1px solid #30363d", borderRadius: 8, padding: 16 }}>
            <div className="skeleton" style={{ width: "60%", height: 12, marginBottom: 8, borderRadius: 4 }} />
            <div className="skeleton" style={{ width: "40%", height: 20, borderRadius: 4 }} />
          </div>
        ))}
      </div>
      <div className="dashboard-actions">
        {[1,2,3].map(i => <div key={i} className="skeleton" style={{ flex: 1, height: 40, borderRadius: 8 }} />)}
      </div>
    </div>
  );
  if (error) return <div className="admin-error"><p>Error: {error}</p></div>;
  if (!member) return <div className="admin-loading"><p>Member profile not found. Contact admin.</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Welcome, {member.name}</h1>
        <div style={{ position: "relative", display: "flex", gap: 8 }}>
          <button
            className="btn-icon"
            title="Notifications"
            onClick={() => navigate("/member/notifications")}
            style={{ position: "relative" }}
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
            {unreadCount > 0 && (
              <span style={{
                position: "absolute", top: -2, right: -2,
                background: "#f59e0b", color: "#000",
                fontSize: 10, fontWeight: 700,
                width: 18, height: 18, borderRadius: "50%",
                display: "flex", alignItems: "center", justifyContent: "center",
              }}>
                {unreadCount}
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Contribution Card */}
      <div className="section">
        <div className="chart-card">
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ margin: 0, color: "#c9d1d9", fontSize: 14, fontWeight: 600 }}>My Contributions</h3>
            <span className="chip active-chip">{contributions.length} payments</span>
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: "#22c55e", marginBottom: 12 }}>
            ₱{formatCurrency(totalContributions)}
          </div>
          {fullMonthlyRequired > 0 && (
            <>
              <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
                <span style={{ fontSize: 13, fontWeight: 600, color: totalThisMonth >= fullMonthlyRequired ? "#22c55e" : "#f59e0b" }}>
                  This month: ₱{formatCurrency(totalThisMonth)}
                </span>
                <span style={{ fontSize: 12, color: "#8b949e" }}>Required: ₱{formatCurrency(fullMonthlyRequired)}</span>
              </div>
              <div style={{ height: 6, background: "#1c2128", borderRadius: 3, overflow: "hidden" }}>
                <div style={{ width: `${progress * 100}%`, height: "100%", background: totalThisMonth >= fullMonthlyRequired ? "#22c55e" : "#f59e0b", borderRadius: 3 }} />
              </div>
            </>
          )}
          {member.balance > 0 && (
            <div style={{ marginTop: 8, display: "flex", alignItems: "center", gap: 6 }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/></svg>
              <span style={{ color: "#22c55e", fontSize: 13, fontWeight: 600 }}>Credit balance: ₱{formatCurrency(member.balance)}</span>
            </div>
          )}
          <div style={{ marginTop: 8, display: "flex", alignItems: "center", gap: 6 }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={cutoffColor} strokeWidth="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            <span style={{ color: cutoffColor, fontSize: 13, fontWeight: 500 }}>{cutoffLabel}</span>
          </div>
        </div>
      </div>

      {/* Stat Chips */}
      <div className="mini-stats">
        <div className="mini-stat accent">
          <span className="mini-stat-label">My Contributions</span>
          <span className="mini-stat-value">₱{formatCurrency(totalContributions)}</span>
        </div>
        <div className="mini-stat warning">
          <span className="mini-stat-label">Active Loans</span>
          <span className="mini-stat-value">{activeLoans.length}</span>
        </div>
        <div className="mini-stat">
          <span className="mini-stat-label">Pending</span>
          <span className="mini-stat-value">{totalPending}</span>
        </div>
        <div className="mini-stat accent">
          <span className="mini-stat-label">Heads</span>
          <span className="mini-stat-value">{member.headsCount}</span>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="dashboard-actions">
        <button className="btn btn-primary" onClick={() => {
          if (totalThisMonth >= perCutoffAmount && fullMonthlyRequired > 0) {
            setShowTrackDialog(true);
          } else {
            setShowPaymentModal(true);
          }
        }}>
          + Pay Contribution
        </button>
        <button className="btn btn-outline" style={{ borderColor: "#f59e0b", color: "#f59e0b" }} onClick={() => setShowLoanModal(true)}>
          + Request Loan
        </button>
        <button className="btn btn-outline" style={{ borderColor: "#3b82f6", color: "#3b82f6" }} onClick={() => setShowHeadModal(true)}>
          Change Heads
        </button>
      </div>

      {/* Returns Section */}
      <div className="annual-returns">
        <div className="annual-returns-title">End of Year Returns</div>
        <div className="mini-stats">
          <div className="mini-stat accent">
            <span className="mini-stat-label">Returns Pool</span>
            <span className="mini-stat-value">₱{formatCurrency(totalInterestEarned)}</span>
          </div>
          <div className="mini-stat">
            <span className="mini-stat-label">Per Head Share</span>
            <span className="mini-stat-value">₱{formatCurrency(perHeadShare)}</span>
          </div>
          <div className="mini-stat">
            <span className="mini-stat-label">My Heads</span>
            <span className="mini-stat-value">{totalHeadsCount}</span>
          </div>
        </div>
      </div>

      {/* Active Loans */}
      <div className="section">
        <h2>Active Loans</h2>
        {activeLoans.length === 0 ? (
          <p className="empty-text">No active loans</p>
        ) : (
          <div className="activity-list">
            {activeLoans.map(loan => {
              const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
              const remaining = loan.remainingBalance ?? totalDue;
              const loanProgress = totalDue > 0 ? (totalDue - remaining) / totalDue : 0;
              const dueDate = loan.dueDate?.toDate?.();
              const isOverdue = dueDate && dueDate < now;
              const daysOverdue = dueDate ? Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24)) : 0;

              return (
                <div key={loan.id} className="approval-card" style={{ marginBottom: 12 }}>
                  <div className="approval-top">
                    <div>
                      <strong>Loan #{loan.id.slice(0, 5)}</strong>
                      <span style={{ marginLeft: 8, fontSize: 12, color: "#8b949e" }}>{(loan.interestRate * 100).toFixed(0)}% interest</span>
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
                      <div style={{ width: `${loanProgress * 100}%`, height: "100%", background: isOverdue ? "#ef4444" : "#f59e0b", borderRadius: 3 }} />
                    </div>
                    <span style={{ fontSize: 11, color: "#8b949e" }}>{(loanProgress * 100).toFixed(0)}%</span>
                  </div>
                  <div className="approval-details">
                    <span>Principal: ₱{formatCurrency(loan.principal)}</span>
                    <span>Due: {dueDate?.toLocaleDateString() || "N/A"}</span>
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

      {/* Track Dialog */}
      {showTrackDialog && (
        <div className="modal-overlay" onClick={() => setShowTrackDialog(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 400, textAlign: "center" }}>
            <div className="modal-header">
              <h2>YOU'RE ON TRACK!</h2>
              <button className="btn-icon" onClick={() => setShowTrackDialog(false)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>
            <div style={{ padding: "24px 0" }}>
              <div style={{ fontSize: 48, marginBottom: 16 }}>🎯</div>
              <p style={{ color: "#22c55e", fontSize: 16, fontWeight: 600, marginBottom: 12 }}>
                You've met your contribution for this cutoff period.
              </p>
              <p style={{ color: "#8b949e", fontSize: 14 }}>
                Contributed: ₱{formatCurrency(totalThisMonth)} / ₱{formatCurrency(perCutoffAmount)} this cutoff
              </p>
              <div style={{ display: "flex", gap: 12, justifyContent: "center", marginTop: 24 }}>
                <button className="btn btn-primary" onClick={() => setShowTrackDialog(false)}>
                  Close
                </button>
                <button
                  className="btn btn-outline"
                  style={{ borderColor: "#22c55e", color: "#22c55e" }}
                  onClick={() => { setShowTrackDialog(false); setPaymentModalDefaultAdvance(true); setShowPaymentModal(true); }}
                >
                  Pay in Advance
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Modals */}
      {showPaymentModal && member && (
        <PaymentModal
          memberId={member.memberId}
          memberDocId={memberDocId}
          memberName={member.name}
          headsCount={member.headsCount}
          totalRequired={fullMonthlyRequired}
          balance={member.balance}
          onClose={() => { setShowPaymentModal(false); setPaymentModalDefaultAdvance(false); }}
          defaultAdvance={paymentModalDefaultAdvance || undefined}
        />
      )}
      {showLoanModal && (
        <LoanRequestModal memberDocId={memberDocId} onClose={() => setShowLoanModal(false)} />
      )}
      {showHeadModal && member && (
        <HeadChangeModal
          memberDocId={memberDocId}
          currentHeads={member.headsCount}
          onClose={() => setShowHeadModal(false)}
        />
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

export default Dashboard;
