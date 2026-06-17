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
  getDocs,
  updateDoc,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";
import { useNavigate } from "react-router-dom";
import PaymentModal from "./modals/PaymentModal";
import LoanRequestModal from "./modals/LoanRequestModal";
import HeadChangeModal from "./modals/HeadChangeModal";
import RepaymentModal from "./modals/RepaymentModal";
import { computeCutoff, CutoffState } from "../../utils/cutoffCalculator";

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
  const [notifications, setNotifications] = useState<{id: string; title: string; body: string; read: boolean; createdAt: Timestamp; type?: string}[]>([]);
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
  const [showNotifDropdown, setShowNotifDropdown] = useState(false);

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
      async (snap) => {
        const loanList = snap.docs.map(d => ({ id: d.id, ...d.data() } as Loan));
        const withBalances = await Promise.all(loanList.map(async (loan) => {
          if (loan.isFullyRepaid) {
            const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
            return { ...loan, remainingBalance: 0, totalRepaid: totalDue };
          }
          const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
          const repayQ = query(collection(db, "repayments"), where("loanId", "==", loan.id));
          const repaySnap = await getDocs(repayQ);
          let repaid = 0;
          repaySnap.docs.forEach(d => { repaid += Number(d.data().amountPaid) || 0; });
          return { ...loan, remainingBalance: Math.max(0, totalDue - repaid), totalRepaid: repaid };
        }));
        setLoans(withBalances);
      },
      (err) => { console.error("[Dashboard] loans error:", err); }
    ));

    unsubs.push(onSnapshot(
      query(collection(db, "payment_requests"), where("memberId", "==", member.id), orderBy("requestDate", "desc")),
      (snap) => { setPaymentRequests(snap.docs.map(d => ({ id: d.id, ...d.data() } as PaymentRequest))); },
      (err) => { console.error("[Dashboard] payment_requests error:", err); }
    ));

    if (user?.uid) {
      unsubs.push(onSnapshot(
        query(collection(db, "notifications"), where("userId", "==", user.uid), orderBy("createdAt", "desc")),
        (snap) => {
          setNotifications(snap.docs.map(d => ({ id: d.id, ...d.data() } as {id: string; title: string; body: string; read: boolean; createdAt: Timestamp; type?: string})));
          setUnreadCount(snap.docs.filter(d => !d.data().read).length);
        }
      ));
    }

    return () => unsubs.forEach(u => u());
  }, [member?.id, user?.uid]);

  const now = new Date();
  const totalContributions = contributions.reduce((s, c) => s + (Number(c.amount) || 0), 0);
  const activeLoans = loans.filter(l => !l.isFullyRepaid);
  const pendingCount = paymentRequests.filter(p => p.status === "pending").length;
  const totalPending = pendingCount;

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

  const totalInterestEarned = loans.reduce((s, l) => {
    const repaid = (l as any).totalRepaid || 0;
    const interest = repaid - (Number(l.principal) || 0);
    return s + (interest > 0 ? interest : 0);
  }, 0);
  const perHeadShare = totalHeadsCount > 0 ? totalInterestEarned / totalHeadsCount : 0;

  const perCutoffMet = perCutoffAmount > 0 && totalThisMonth >= perCutoffAmount;
  const fullMonthMet = fullMonthlyRequired > 0 && totalThisMonth >= fullMonthlyRequired;
  const cutoffInfo = computeCutoff(now, cutoffDay1, cutoffDay2);
  const cutoffLabel = fullMonthMet ? "✓ Paid" : perCutoffMet ? "✓ Cutoff Met" : cutoffInfo.statusText;
  const cutoffColor = fullMonthMet ? "#22c55e" : perCutoffMet ? "#22c55e" : cutoffInfo.statusColor;
  const cutoffProgress = Math.max(0, Math.min(100, (1 - Math.max(0, cutoffInfo.daysUntilNext) / 30) * 100));

  if (loading) return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Welcome</h1>
      </div>
      <div className="mini-stats">
        {[1,2,3,4].map(i => (
          <div key={i} className="mini-stat" style={{ border: "1px solid #30363d", borderRadius: 8, padding: 16 }}>
            <div className="skeleton" style={{ width: "60%", height: 10, margin: "0 auto 8px", borderRadius: 4 }} />
            <div className="skeleton" style={{ width: "40%", height: 18, margin: "0 auto", borderRadius: 4 }} />
          </div>
        ))}
      </div>
      <div className="dashboard-actions">
        {[1,2,3].map(i => <div key={i} className="skeleton" style={{ flex: 1, height: 40, borderRadius: 8 }} />)}
      </div>
      <div className="section">
        <div className="activity-group-header">
          <div className="skeleton" style={{ width: 140, height: 14, borderRadius: 4 }} />
          <div className="skeleton" style={{ flex: 1, height: 1, borderRadius: 0 }} />
        </div>
        <div className="chart-card">
          <div className="skeleton" style={{ width: "40%", height: 14, marginBottom: 16, borderRadius: 4 }} />
          <div className="skeleton" style={{ width: "30%", height: 32, marginBottom: 12, borderRadius: 4 }} />
          <div className="skeleton" style={{ width: "100%", height: 6, marginBottom: 12, borderRadius: 3 }} />
          <div className="skeleton" style={{ width: "50%", height: 12, borderRadius: 4 }} />
        </div>
      </div>
      <div className="section">
        <div className="activity-group-header">
          <div className="skeleton" style={{ width: 120, height: 14, borderRadius: 4 }} />
          <div className="skeleton" style={{ flex: 1, height: 1, borderRadius: 0 }} />
        </div>
        <div className="skeleton" style={{ width: "100%", height: 80, borderRadius: 10 }} />
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
          <div style={{ position: "relative" }}>
            <button
              className="btn-icon"
              title="Notifications"
              onClick={() => setShowNotifDropdown(v => !v)}
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
            {showNotifDropdown && (
              <>
                <div className="modal-overlay" style={{ position: "fixed", inset: 0, zIndex: 999, background: "transparent" }} onClick={() => setShowNotifDropdown(false)} />
                <div style={{
                  position: "absolute", top: "100%", right: 0, zIndex: 1000,
                  width: 340, maxHeight: 400, overflow: "auto",
                  background: "#161b22", border: "1px solid #30363d",
                  borderRadius: 12, boxShadow: "0 8px 32px rgba(0,0,0,0.5)",
                  padding: 8,
                }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "8px 12px", borderBottom: "1px solid #21262d", marginBottom: 4 }}>
                    <strong style={{ fontSize: 14 }}>Notifications</strong>
                    {unreadCount > 0 && <span style={{ fontSize: 11, color: "#8b949e" }}>{unreadCount} unread</span>}
                  </div>
                  {notifications.length === 0 ? (
                    <p style={{ textAlign: "center", color: "#8b949e", fontSize: 12, padding: "20px 0" }}>No notifications</p>
                  ) : (
                    notifications.slice(0, 5).map(n => (
                      <div key={n.id} style={{
                        padding: "10px 12px", borderRadius: 8, cursor: "pointer",
                        background: n.read ? "transparent" : "rgba(34,197,94,0.06)",
                        transition: "background 0.15s",
                      }}
                        onMouseEnter={e => (e.currentTarget.style.background = "rgba(255,255,255,0.03)")}
                        onMouseLeave={e => (e.currentTarget.style.background = n.read ? "transparent" : "rgba(34,197,94,0.06)")}
                        onClick={async () => {
                          try { await updateDoc(doc(db, "notifications", n.id), { read: true }); } catch {}
                          setShowNotifDropdown(false);
                        }}
                      >
                        <div style={{ fontSize: 13, fontWeight: n.read ? 400 : 600, color: "#f0f6fc", marginBottom: 2 }}>{n.title}</div>
                        <div style={{ fontSize: 11, color: "#8b949e", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{n.body}</div>
                      </div>
                    ))
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Cutoff Countdown Card */}
      <div className="section">
        <div className="chart-card" style={{ border: `1px solid ${cutoffColor}33`, position: "relative", overflow: "hidden" }}>
          <div style={{
            position: "absolute", top: 0, left: 0, bottom: 0,
            width: `${cutoffProgress}%`, background: `${cutoffColor}0d`,
            transition: "width 0.5s ease",
          }} />
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={cutoffColor} strokeWidth="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
              <span style={{ fontSize: 13, fontWeight: 600, color: "#c9d1d9" }}>Next Cutoff</span>
            </div>
            <span className={`chip ${fullMonthMet || perCutoffMet ? "active-chip" : cutoffInfo.state === CutoffState.dueToday ? "inactive-chip" : cutoffInfo.state === CutoffState.nearDeadline ? "badge-orange" : "active-chip"}`}>
              {cutoffLabel}
            </span>
          </div>
          <div style={{ fontSize: 26, fontWeight: 800, color: cutoffColor, marginBottom: 8 }}>
            {fullMonthMet ? "✓ All Paid" : perCutoffMet ? "✓ Cutoff Met" : cutoffInfo.state === CutoffState.dueToday ? "Due Today" : `${cutoffInfo.daysUntilNext} day${cutoffInfo.daysUntilNext !== 1 ? "s" : ""}`}
          </div>
          <div style={{ height: 4, background: "#1c2128", borderRadius: 2, overflow: "hidden" }}>
            <div style={{
              width: `${cutoffProgress}%`,
              height: "100%", background: cutoffColor, borderRadius: 2,
              transition: "width 0.5s ease",
            }} />
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6 }}>
            <span style={{ fontSize: 11, color: "#8b949e" }}>Cutoff day {cutoffDay1}/{cutoffDay2}</span>
            <span style={{ fontSize: 11, color: "#8b949e" }}>
              {member.amountPerHead > 0 ? `₱${formatCurrency(perCutoffAmount)} per cutoff` : ""}
            </span>
          </div>
        </div>
      </div>

      {/* Mini Stats */}
      <div className="mini-stats">
        <div className="mini-stat accent">
          <span className="mini-stat-label">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: "middle", marginRight: 4 }}><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/></svg>
            Total Contributions
          </span>
          <span className="mini-stat-value">₱{formatCurrency(totalContributions)}</span>
        </div>
        <div className="mini-stat warning">
          <span className="mini-stat-label">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: "middle", marginRight: 4 }}><polygon points="12 2 22 7 22 17 12 22 2 17 2 7 12 2"/><line x1="12" y1="22" x2="12" y2="7"/></svg>
            Active Loans
          </span>
          <span className="mini-stat-value">{activeLoans.length}</span>
        </div>
        <div className="mini-stat">
          <span className="mini-stat-label">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: "middle", marginRight: 4 }}><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            Pending
          </span>
          <span className="mini-stat-value">{totalPending}</span>
        </div>
        <div className="mini-stat accent">
          <span className="mini-stat-label">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: "middle", marginRight: 4 }}><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            Heads
          </span>
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
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: "middle", marginRight: 6 }}><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/></svg>
          Pay Contribution
        </button>
        <button className="btn btn-outline" style={{ borderColor: "#f59e0b", color: "#f59e0b" }} onClick={() => setShowLoanModal(true)}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: "middle", marginRight: 6 }}><polygon points="12 2 22 7 22 17 12 22 2 17 2 7 12 2"/><line x1="12" y1="22" x2="12" y2="7"/></svg>
          Request Loan
        </button>
        <button className="btn btn-outline" style={{ borderColor: "#3b82f6", color: "#3b82f6" }} onClick={() => setShowHeadModal(true)}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ verticalAlign: "middle", marginRight: 6 }}><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          Change Heads
        </button>
      </div>

      {/* My Contributions Section */}
      <div className="section">
        <div className="activity-group-header">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/></svg>
          <span className="activity-group-label">My Contributions</span>
          <span className="activity-group-line" />
        </div>
        <div className="chart-card">
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ margin: 0, color: "#c9d1d9", fontSize: 14, fontWeight: 600 }}>Total Contributed</h3>
            <span className="chip active-chip">{contributions.length} payment{contributions.length !== 1 ? "s" : ""}</span>
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
                <div style={{ width: `${progress * 100}%`, height: "100%", background: totalThisMonth >= fullMonthlyRequired ? "#22c55e" : "#f59e0b", borderRadius: 3, transition: "width 0.5s ease" }} />
              </div>
            </>
          )}
          {member.balance > 0 && (
            <div style={{ marginTop: 8, display: "flex", alignItems: "center", gap: 6 }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/></svg>
              <span style={{ color: "#22c55e", fontSize: 13, fontWeight: 600 }}>Credit balance: ₱{formatCurrency(member.balance)}</span>
            </div>
          )}
        </div>
      </div>

      {/* Annual Returns Section */}
      <div className="annual-returns">
        <div className="activity-group-header" style={{ margin: "0 0 16px" }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2"><line x1="12" y1="20" x2="12" y2="10"/><line x1="18" y1="20" x2="18" y2="4"/><line x1="6" y1="20" x2="6" y2="16"/></svg>
          <span className="activity-group-label">End of Year Returns</span>
          <span className="activity-group-line" />
        </div>
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

      {/* Active Loans Section */}
      <div className="section">
        <div className="activity-group-header">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2"><polygon points="12 2 22 7 22 17 12 22 2 17 2 7 12 2"/><line x1="12" y1="22" x2="12" y2="7"/></svg>
          <span className="activity-group-label">Active Loans</span>
          <span className="activity-group-line" />
          {activeLoans.length > 0 && (
            <span className="chip badge-orange">{activeLoans.length} active</span>
          )}
        </div>
        {activeLoans.length === 0 ? (
          <p className="empty-text">No active loans</p>
        ) : (
          <div className="activity-feed">
            {activeLoans.map(loan => {
              const totalDue = loan.principal + (loan.principal * (loan.interestRate || 0));
              const remaining = loan.remainingBalance ?? totalDue;
              const loanProgress = totalDue > 0 ? (totalDue - remaining) / totalDue : 0;
              const dueDate = loan.dueDate?.toDate?.();
              const isOverdue = dueDate && dueDate < now;
              const daysOverdue = dueDate ? Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24)) : 0;

              return (
                <div key={loan.id} className="activity-card" style={{ marginBottom: 8, flexWrap: "wrap" }}>
                  <div className={`activity-card-icon ${isOverdue ? "activity-icon-loan" : "activity-icon-contribution"}`}>
                    {isOverdue ? "\u26A0\uFE0F" : "\uD83C\uDFE6"}
                  </div>
                  <div className={`activity-card-dot ${isOverdue ? "activity-dot-error" : "activity-dot-pending"}`} />
                  <div className="activity-card-body">
                    <div className="activity-card-title">
                      Loan #{loan.id.slice(0, 5)}
                      <span style={{ marginLeft: 8, fontSize: 12, color: "#8b949e", fontWeight: 400 }}>
                        {(loan.interestRate * 100).toFixed(0)}% interest
                      </span>
                    </div>
                    <div className="activity-card-meta">
                      <span>Principal: ₱{formatCurrency(loan.principal)}</span>
                      <span className="meta-sep">|</span>
                      <span>Due: {dueDate?.toLocaleDateString() || "N/A"}</span>
                      {isOverdue && (
                        <>
                          <span className="meta-sep">|</span>
                          <span style={{ color: "#ef4444" }}>{daysOverdue}d overdue</span>
                        </>
                      )}
                    </div>
                    <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 6 }}>
                      <div style={{ flex: 1, height: 4, background: "#1c2128", borderRadius: 2, overflow: "hidden" }}>
                        <div style={{ width: `${loanProgress * 100}%`, height: "100%", background: isOverdue ? "#ef4444" : "#f59e0b", borderRadius: 2 }} />
                      </div>
                      <span style={{ fontSize: 11, color: "#8b949e", fontWeight: 600 }}>{(loanProgress * 100).toFixed(0)}%</span>
                    </div>
                  </div>
                  <div className="activity-card-end">
                    <div className={`activity-card-amount ${isOverdue ? "activity-amount-error" : "activity-amount-pending"}`}>
                      ₱{formatCurrency(remaining)}
                    </div>
                    <button
                      className="btn btn-sm"
                      style={{
                        background: "rgba(245, 158, 11, 0.1)",
                        color: "#f59e0b",
                        border: "1px solid rgba(245, 158, 11, 0.2)",
                        borderRadius: 6,
                        padding: "4px 10px",
                        fontSize: 11,
                        fontWeight: 600,
                        cursor: "pointer",
                      }}
                      onClick={() => { setRepayLoan(loan); setShowRepaymentModal(true); }}
                    >
                      Repay
                    </button>
                  </div>
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
