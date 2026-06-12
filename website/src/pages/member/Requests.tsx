import React, { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  Timestamp,
  addDoc,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";

interface PaymentRequest {
  id: string;
  memberId: string;
  amount: number;
  type: string;
  status: string;
  requestDate: Timestamp;
  approvedDate?: Timestamp;
  notes?: string;
  loanId?: string;
  receiptPath?: string;
  receiptUrl?: string;
  rejectReason?: string;
}

interface LoanRequest {
  id: string;
  memberId: string;
  amount: number;
  interestRate: number;
  dueDate: Timestamp;
  status: string;
  requestedAt: Timestamp;
  processedAt?: Timestamp;
  notes?: string;
}

interface HeadChangeRequest {
  id: string;
  memberId: string;
  currentHeads: number;
  requestedHeads: number;
  status: string;
  requestedAt: Timestamp;
  processedAt?: Timestamp;
  reason?: string;
  notes?: string;
}

type TabType = "payments" | "loans" | "heads";

const Requests: React.FC = () => {
  const { user } = useMemberAuth();
  const memberDocId = user?.memberId;
  const [tab, setTab] = useState<TabType>("payments");
  const [showLoanModal, setShowLoanModal] = useState(false);

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>My Requests</h1>
        {tab === "loans" && (
          <button className="btn btn-primary btn-sm" onClick={() => setShowLoanModal(true)}>
            + Request Loan
          </button>
        )}
      </div>

      <TabPills active={tab} onChange={setTab} memberId={memberDocId} />
      <TabStats tab={tab} memberId={memberDocId} />

      {tab === "payments" && <PaymentsTab memberId={memberDocId} />}
      {tab === "loans" && (
        <>
          <LoansTab memberId={memberDocId} />
          {showLoanModal && <LoanRequestModal memberDocId={memberDocId} onClose={() => setShowLoanModal(false)} />}
        </>
      )}
      {tab === "heads" && <HeadsTab memberId={memberDocId} />}
    </div>
  );
};

/* Tab Pills with pending badge */
const TabPills: React.FC<{ active: TabType; onChange: (t: TabType) => void; memberId: string | undefined }> = ({ active, onChange, memberId }) => {
  const [counts, setCounts] = useState<Record<TabType, number>>({ payments: 0, loans: 0, heads: 0 });

  useEffect(() => {
    if (!memberId) return;
    const unsubs: (() => void)[] = [];
    const configs: { tab: TabType; col: string }[] = [
      { tab: "payments", col: "payment_requests" },
      { tab: "loans", col: "loan_requests" },
      { tab: "heads", col: "head_change_requests" },
    ];
    configs.forEach(({ tab, col }) => {
      const u = onSnapshot(
        query(collection(db, col), where("memberId", "==", memberId), where("status", "==", "pending")),
        (snap) => setCounts(prev => ({ ...prev, [tab]: snap.size })),
        () => {}
      );
      unsubs.push(u);
    });
    return () => unsubs.forEach(u => u());
  }, [memberId]);

  const labels: Record<TabType, string> = { payments: "Payments", loans: "Loans", heads: "Heads" };

  return (
    <div className="tabs" style={{ marginBottom: 16 }}>
      {(Object.keys(labels) as TabType[]).map(t => (
        <button key={t} className={`tab ${active === t ? "active" : ""}`} onClick={() => onChange(t)}>
          {labels[t]}
          {counts[t] > 0 && (
            <span style={{
              marginLeft: 6,
              background: "#f59e0b",
              color: "#000",
              fontSize: 10,
              fontWeight: 800,
              borderRadius: 10,
              padding: "1px 6px",
              lineHeight: "16px",
            }}>
              {counts[t]}
            </span>
          )}
        </button>
      ))}
    </div>
  );
};

/* Stats summary row */
const TabStats: React.FC<{ tab: TabType; memberId: string | undefined }> = ({ tab, memberId }) => {
  const [stats, setStats] = useState({ total: 0, pending: 0, approved: 0, rejected: 0, disbursed: 0 });

  useEffect(() => {
    if (!memberId) return;
    const colMap: Record<TabType, string> = { payments: "payment_requests", loans: "loan_requests", heads: "head_change_requests" };
    const col = colMap[tab];
    if (!col) return;
    const unsub = onSnapshot(
      query(collection(db, col), where("memberId", "==", memberId)),
      (snap) => {
        const docs = snap.docs.map(d => d.data());
        const pending = docs.filter(d => d.status === "pending").length;
        const approved = docs.filter(d => d.status === "approved").length;
        const rejected = docs.filter(d => d.status === "rejected").length;
        const disbursed = docs.filter(d => d.status === "disbursed").length;
        setStats({ total: docs.length, pending, approved, rejected, disbursed });
      },
      () => {}
    );
    return unsub;
  }, [tab, memberId]);

  const items = [
    { label: "Total", count: stats.total, color: "#8b949e" },
    { label: "Pending", count: stats.pending, color: "#f59e0b" },
    { label: "Approved", count: stats.approved, color: "#22c55e" },
    { label: "Rejected", count: stats.rejected, color: "#ef4444" },
  ];
  if (tab === "loans") items.splice(3, 0, { label: "Disbursed", count: stats.disbursed, color: "#3b82f6" });

  return (
    <div style={{ display: "flex", gap: 8, marginBottom: 16, flexWrap: "wrap" }}>
      {items.map(i => (
        <div key={i.label} style={{
          flex: 1,
          minWidth: 80,
          background: "#1c2128",
          border: "1px solid #21262d",
          borderRadius: 8,
          padding: "10px 14px",
          textAlign: "center",
        }}>
          <div style={{ fontSize: 20, fontWeight: 800, color: i.color }}>{i.count}</div>
          <div style={{ fontSize: 11, color: "#8b949e", marginTop: 2 }}>{i.label}</div>
        </div>
      ))}
    </div>
  );
};

const formatCurrency = (n: number) =>
  n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatDate = (ts: Timestamp | undefined) => {
  if (!ts?.toDate) return "N/A";
  const d = ts.toDate();
  const diff = Math.floor((Date.now() - d.getTime()) / (1000 * 60 * 60 * 24));
  if (diff === 0) return "Today";
  if (diff === 1) return "Yesterday";
  if (diff < 7) return `${diff}d ago`;
  return d.toLocaleDateString();
};

/* SVG status icons */
const statusSvgIcon = (status: string, size = 18) => {
  const icons: Record<string, { viewBox: string; path: string; color: string }> = {
    pending: {
      viewBox: "0 0 24 24",
      path: "<circle cx='12' cy='12' r='10'/><polyline points='12,6 12,12 16,14'/>",
      color: "#f59e0b",
    },
    approved: {
      viewBox: "0 0 24 24",
      path: "<circle cx='12' cy='12' r='10'/><polyline points='9,12 11,14 15,10'/>",
      color: "#22c55e",
    },
    rejected: {
      viewBox: "0 0 24 24",
      path: "<circle cx='12' cy='12' r='10'/><line x1='15' y1='9' x2='9' y2='15'/><line x1='9' y1='9' x2='15' y2='15'/>",
      color: "#ef4444",
    },
    disbursed: {
      viewBox: "0 0 24 24",
      path: "<circle cx='12' cy='12' r='10'/><rect x='9' y='7' width='6' height='10' rx='1'/><line x1='12' y1='11' x2='12' y2='13'/>",
      color: "#3b82f6",
    },
  };
  const cfg = icons[status] || icons.pending;
  return (
    <svg width={size} height={size} viewBox={cfg.viewBox} fill="none" stroke={cfg.color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <g dangerouslySetInnerHTML={{ __html: cfg.path }} />
    </svg>
  );
};

const statusBadge = (status: string) => {
  const map: Record<string, { color: string; bg: string }> = {
    pending: { color: "#f59e0b", bg: "rgba(245,158,11,0.15)" },
    approved: { color: "#22c55e", bg: "rgba(34,197,94,0.15)" },
    rejected: { color: "#ef4444", bg: "rgba(239,68,68,0.15)" },
    disbursed: { color: "#3b82f6", bg: "rgba(59,130,246,0.15)" },
  };
  const s = map[status] || map.pending;
  return (
    <span className="chip" style={{ background: s.bg, color: s.color, fontSize: 11, display: "inline-flex", alignItems: "center", gap: 4 }}>
      {statusSvgIcon(status, 12)}
      {status.toUpperCase()}
    </span>
  );
};

/* Payment type icons */
const typeSvgIcon = (type: string) => {
  if (type === "loan") {
    return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="2" y="6" width="20" height="12" rx="2" />
        <circle cx="12" cy="12" r="2" />
        <path d="M6 12h.01" />
        <path d="M18 12h.01" />
      </svg>
    );
  }
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#3b82f6" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 2v20" />
      <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
    </svg>
  );
};

/* Detail Modal */
const PaymentDetailModal: React.FC<{ request: PaymentRequest; onClose: () => void }> = ({ request: r, onClose }) => {
  const statusColors: Record<string, { bg: string; color: string; label: string }> = {
    pending: { bg: "rgba(245,158,11,0.15)", color: "#f59e0b", label: "Pending Review" },
    approved: { bg: "rgba(34,197,94,0.15)", color: "#22c55e", label: "Approved" },
    rejected: { bg: "rgba(239,68,68,0.15)", color: "#ef4444", label: "Rejected" },
  };
  const sc = statusColors[r.status] || statusColors.pending;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
        <div className="modal-header">
          <h2>Payment Detail</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div style={{ textAlign: "center", padding: "24px 0" }}>
          <div style={{ marginBottom: 8 }}>{statusSvgIcon(r.status, 48)}</div>
          <h3 style={{ color: sc.color, margin: "0 0 4px" }}>{sc.label}</h3>
          <div style={{ fontSize: 32, fontWeight: 800, color: "#fff" }}>₱{formatCurrency(r.amount)}</div>
          {r.type === "loan" && <div style={{ fontSize: 13, color: "#f59e0b", marginTop: 4 }}>Loan Repayment</div>}
          {r.type === "contribution" && <div style={{ fontSize: 13, color: "#3b82f6", marginTop: 4 }}>Contribution Payment</div>}
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 12, marginBottom: 16 }}>
          <div className="detail-row">
            <span className="detail-label">Submitted</span>
            <span className="detail-value">{r.requestDate?.toDate?.()?.toLocaleString() || "N/A"}</span>
          </div>
          {r.approvedDate && (
            <div className="detail-row">
              <span className="detail-label">Processed</span>
              <span className="detail-value">{r.approvedDate?.toDate?.()?.toLocaleString() || "N/A"}</span>
            </div>
          )}
          {r.type === "loan" && r.loanId && (
            <div className="detail-row">
              <span className="detail-label">Loan ID</span>
              <span className="detail-value" style={{ fontSize: 12 }}>{r.loanId}</span>
            </div>
          )}
          {r.notes && (
            <div className="detail-row">
              <span className="detail-label">Notes</span>
              <span className="detail-value">{r.notes}</span>
            </div>
          )}
          {r.rejectReason && r.status === "rejected" && (
            <div className="detail-row" style={{ borderColor: "#ef444433" }}>
              <span className="detail-label" style={{ color: "#ef4444" }}>Rejection Reason</span>
              <span className="detail-value" style={{ color: "#ef4444" }}>{r.rejectReason}</span>
            </div>
          )}
        </div>

        {(r.receiptPath || r.receiptUrl) && (
          <div style={{ border: "1px solid #21262d", borderRadius: 8, overflow: "hidden" }}>
            <div style={{ padding: "8px 12px", background: "#1c2128", fontSize: 12, color: "#8b949e", fontWeight: 600 }}>
              RECEIPT
            </div>
            <img
              src={r.receiptPath || r.receiptUrl}
              alt="Receipt"
              style={{ width: "100%", maxHeight: 300, objectFit: "contain", display: "block" }}
            />
          </div>
        )}
      </div>
    </div>
  );
};

/* Payments Tab */
const PaymentsTab: React.FC<{ memberId: string | undefined }> = ({ memberId }) => {
  const [requests, setRequests] = useState<PaymentRequest[]>([]);
  const [filter, setFilter] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<PaymentRequest | null>(null);

  useEffect(() => {
    if (!memberId) return;
    const unsub = onSnapshot(
      query(collection(db, "payment_requests"), where("memberId", "==", memberId), orderBy("requestDate", "desc")),
      (snap) => { setRequests(snap.docs.map(d => ({ id: d.id, ...d.data() } as PaymentRequest))); setLoading(false); },
      () => setLoading(false)
    );
    return unsub;
  }, [memberId]);

  const filtered = filter ? requests.filter(r => r.status === filter) : requests;
  const pending = requests.filter(r => r.status === "pending").length;
  const approved = requests.filter(r => r.status === "approved").length;
  const rejected = requests.filter(r => r.status === "rejected").length;

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;

  const filterTabs: { label: string; count: number; key: string | null }[] = [
    { label: "All", count: requests.length, key: null },
    { label: "Pending", count: pending, key: "pending" },
    { label: "Approved", count: approved, key: "approved" },
    { label: "Rejected", count: rejected, key: "rejected" },
  ];

  return (
    <>
      <div className="tabs" style={{ marginBottom: 12 }}>
        {filterTabs.map(t => (
          <button key={t.label} className={`tab ${filter === t.key ? "active" : ""}`} onClick={() => setFilter(t.key)}>
            {t.label} ({t.count})
          </button>
        ))}
      </div>
      {filtered.length === 0 ? (
        <p className="empty-text">No payment requests</p>
      ) : (
        <div className="activity-list">
          {filtered.map(r => (
            <div key={r.id} className="approval-card" style={{ marginBottom: 8, cursor: "pointer" }} onClick={() => setSelected(r)}>
              <div className="approval-top">
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <div style={{
                    width: 38, height: 38, borderRadius: 8,
                    background: r.type === "loan" ? "rgba(245,158,11,0.12)" : "rgba(59,130,246,0.12)",
                    display: "flex", alignItems: "center", justifyContent: "center",
                  }}>
                    {typeSvgIcon(r.type)}
                  </div>
                  <div>
                    <div style={{ fontSize: 18, fontWeight: 700 }}>
                      ₱{formatCurrency(r.amount)}
                    </div>
                    <div style={{ fontSize: 11, color: r.type === "loan" ? "#f59e0b" : "#3b82f6", fontWeight: 600 }}>
                      {r.type === "loan" ? "Loan Repayment" : "Contribution"}
                    </div>
                  </div>
                </div>
                {statusBadge(r.status)}
              </div>
              <div className="approval-details">
                <span>Submitted {formatDate(r.requestDate)}</span>
                {r.loanId && <span style={{ color: "#8b949e", fontSize: 11 }}>ID: {r.loanId}</span>}
              </div>
              {r.approvedDate && (
                <div className="approval-details">
                  <span>Processed {formatDate(r.approvedDate)}</span>
                </div>
              )}
              {r.notes && <p className="approval-notes">{r.notes}</p>}
            </div>
          ))}
        </div>
      )}
      {selected && <PaymentDetailModal request={selected} onClose={() => setSelected(null)} />}
    </>
  );
};

/* Loan Detail Modal */
const LoanDetailModal: React.FC<{ request: LoanRequest; onClose: () => void }> = ({ request: r, onClose }) => {
  const statusConfig: Record<string, { bg: string; color: string; label: string }> = {
    pending: { bg: "rgba(245,158,11,0.15)", color: "#f59e0b", label: "Pending Review" },
    approved: { bg: "rgba(34,197,94,0.15)", color: "#22c55e", label: "Approved" },
    rejected: { bg: "rgba(239,68,68,0.15)", color: "#ef4444", label: "Rejected" },
    disbursed: { bg: "rgba(59,130,246,0.15)", color: "#3b82f6", label: "Disbursed" },
  };
  const sc = statusConfig[r.status] || statusConfig.pending;
  const dueDate = r.dueDate?.toDate?.();
  const isOverdue = dueDate && dueDate < new Date() && r.status === "disbursed";

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
        <div className="modal-header">
          <h2>Loan Detail</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div style={{ textAlign: "center", padding: "24px 0" }}>
          <div style={{ marginBottom: 8 }}>{statusSvgIcon(r.status, 48)}</div>
          <h3 style={{ color: sc.color, margin: "0 0 4px" }}>{sc.label}</h3>
          <div style={{ fontSize: 32, fontWeight: 800, color: "#fff" }}>₱{formatCurrency(r.amount)}</div>
          <div style={{ fontSize: 13, color: "#8b949e", marginTop: 4 }}>{r.interestRate}% interest rate</div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 12, marginBottom: 16 }}>
          <div className="detail-row">
            <span className="detail-label">Requested</span>
            <span className="detail-value">{r.requestedAt?.toDate?.()?.toLocaleString() || "N/A"}</span>
          </div>
          {r.processedAt && (
            <div className="detail-row">
              <span className="detail-label">Processed</span>
              <span className="detail-value">{r.processedAt?.toDate?.()?.toLocaleString() || "N/A"}</span>
            </div>
          )}
          <div className="detail-row">
            <span className="detail-label">Due Date</span>
            <span className="detail-value" style={{ color: isOverdue ? "#ef4444" : undefined }}>
              {dueDate?.toLocaleDateString() || "N/A"}
              {isOverdue && ` (OVERDUE)`}
            </span>
          </div>
          {r.notes && (
            <div className="detail-row">
              <span className="detail-label">Purpose</span>
              <span className="detail-value">{r.notes}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

/* Loans Tab */
const LoansTab: React.FC<{ memberId: string | undefined }> = ({ memberId }) => {
  const [requests, setRequests] = useState<LoanRequest[]>([]);
  const [filter, setFilter] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<LoanRequest | null>(null);

  useEffect(() => {
    if (!memberId) return;
    const unsub = onSnapshot(
      query(collection(db, "loan_requests"), where("memberId", "==", memberId)),
      (snap) => {
        const data = snap.docs.map(d => ({ id: d.id, ...d.data() } as LoanRequest));
        data.sort((a, b) => (b.requestedAt?.toDate?.()?.getTime() || 0) - (a.requestedAt?.toDate?.()?.getTime() || 0));
        setRequests(data);
        setLoading(false);
      },
      () => setLoading(false)
    );
    return unsub;
  }, [memberId]);

  const filtered = filter ? requests.filter(r => r.status === filter) : requests;
  const pending = requests.filter(r => r.status === "pending").length;
  const approved = requests.filter(r => r.status === "approved").length;
  const rejected = requests.filter(r => r.status === "rejected").length;
  const disbursed = requests.filter(r => r.status === "disbursed").length;

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;

  const filterTabs: { label: string; count: number; key: string | null }[] = [
    { label: "All", count: requests.length, key: null },
    { label: "Pending", count: pending, key: "pending" },
    { label: "Approved", count: approved, key: "approved" },
    { label: "Rejected", count: rejected, key: "rejected" },
    { label: "Disbursed", count: disbursed, key: "disbursed" },
  ];

  return (
    <>
      <div className="tabs" style={{ marginBottom: 12, flexWrap: "wrap" }}>
        {filterTabs.map(t => (
          <button key={t.label} className={`tab ${filter === t.key ? "active" : ""}`} onClick={() => setFilter(t.key)}>
            {t.label} ({t.count})
          </button>
        ))}
      </div>
      {filtered.length === 0 ? (
        <p className="empty-text">No loan requests</p>
      ) : (
        <div className="activity-list">
          {filtered.map(r => {
            const dueDate = r.dueDate?.toDate?.();
            const isOverdue = dueDate && dueDate < new Date() && r.status === "disbursed";
            const daysOverdue = dueDate ? Math.floor((Date.now() - dueDate.getTime()) / (1000 * 60 * 60 * 24)) : 0;
            return (
              <div key={r.id} className="approval-card" style={{ marginBottom: 8, cursor: "pointer" }} onClick={() => setSelected(r)}>
                <div className="approval-top">
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <div style={{
                      width: 38, height: 38, borderRadius: 8,
                      background: r.status === "disbursed" ? "rgba(59,130,246,0.12)" : "rgba(245,158,11,0.12)",
                      display: "flex", alignItems: "center", justifyContent: "center",
                    }}>
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
                        stroke={r.status === "disbursed" ? "#3b82f6" : "#f59e0b"}
                        strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <rect x="2" y="6" width="20" height="12" rx="2" />
                        <circle cx="12" cy="12" r="2" />
                        <path d="M6 12h.01" />
                        <path d="M18 12h.01" />
                      </svg>
                    </div>
                    <div>
                      <div style={{ fontSize: 18, fontWeight: 700 }}>₱{formatCurrency(r.amount)}</div>
                      <div style={{ fontSize: 12, color: "#8b949e" }}>{r.interestRate}% interest</div>
                    </div>
                  </div>
                  {statusBadge(r.status)}
                </div>
                <div className="approval-details">
                  <span style={{ color: isOverdue ? "#ef4444" : "#c9d1d9", fontWeight: isOverdue ? 600 : 400 }}>
                    Due: {dueDate?.toLocaleDateString() || "N/A"}
                  </span>
                  {isOverdue && (
                    <span className="chip" style={{ background: "rgba(239,68,68,0.15)", color: "#ef4444" }}>
                      {daysOverdue} days overdue
                    </span>
                  )}
                </div>
                <div className="approval-details">
                  <span>Requested {formatDate(r.requestedAt)}</span>
                </div>
                {r.processedAt && (
                  <div className="approval-details">
                    <span>Processed {formatDate(r.processedAt)}</span>
                  </div>
                )}
                {r.notes && <p className="approval-notes">{r.notes}</p>}
              </div>
            );
          })}
        </div>
      )}
      {selected && <LoanDetailModal request={selected} onClose={() => setSelected(null)} />}
    </>
  );
};

/* Heads Detail Modal */
const HeadChangeDetailModal: React.FC<{ request: HeadChangeRequest; onClose: () => void }> = ({ request: r, onClose }) => {
  const statusConfig: Record<string, { bg: string; color: string; label: string }> = {
    pending: { bg: "rgba(245,158,11,0.15)", color: "#f59e0b", label: "Pending Review" },
    approved: { bg: "rgba(34,197,94,0.15)", color: "#22c55e", label: "Approved" },
    rejected: { bg: "rgba(239,68,68,0.15)", color: "#ef4444", label: "Rejected" },
  };
  const sc = statusConfig[r.status] || statusConfig.pending;
  const diff = r.requestedHeads - r.currentHeads;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
        <div className="modal-header">
          <h2>Head Change Detail</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div style={{ textAlign: "center", padding: "24px 0" }}>
          <div style={{ marginBottom: 8 }}>{statusSvgIcon(r.status, 48)}</div>
          <h3 style={{ color: sc.color, margin: "0 0 4px" }}>{sc.label}</h3>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12 }}>
            <span style={{ fontSize: 28, color: "#8b949e", textDecoration: "line-through" }}>{r.currentHeads}</span>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2">
              <line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>
            </svg>
            <span style={{ fontSize: 32, fontWeight: 800, color: "#fff" }}>{r.requestedHeads}</span>
          </div>
          <div style={{ fontSize: 13, color: "#8b949e", marginTop: 4 }}>
            {diff > 0 ? `+${diff} additional ${diff === 1 ? "head" : "heads"}` : `${diff} ${diff === 1 ? "head" : "heads"}`}
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 12, marginBottom: 16 }}>
          <div className="detail-row">
            <span className="detail-label">Requested</span>
            <span className="detail-value">{r.requestedAt?.toDate?.()?.toLocaleString() || "N/A"}</span>
          </div>
          {r.processedAt && (
            <div className="detail-row">
              <span className="detail-label">Processed</span>
              <span className="detail-value">{r.processedAt?.toDate?.()?.toLocaleString() || "N/A"}</span>
            </div>
          )}
          {(r.reason || r.notes) && (
            <div className="detail-row">
              <span className="detail-label">Reason</span>
              <span className="detail-value">{r.reason || r.notes}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

/* Heads Tab */
const HeadsTab: React.FC<{ memberId: string | undefined }> = ({ memberId }) => {
  const [requests, setRequests] = useState<HeadChangeRequest[]>([]);
  const [filter, setFilter] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<HeadChangeRequest | null>(null);

  useEffect(() => {
    if (!memberId) return;
    const unsub = onSnapshot(
      query(collection(db, "head_change_requests"), where("memberId", "==", memberId), orderBy("requestedAt", "desc")),
      (snap) => { setRequests(snap.docs.map(d => ({ id: d.id, ...d.data() } as HeadChangeRequest))); setLoading(false); },
      () => setLoading(false)
    );
    return unsub;
  }, [memberId]);

  const filtered = filter ? requests.filter(r => r.status === filter) : requests;
  const pending = requests.filter(r => r.status === "pending").length;
  const approved = requests.filter(r => r.status === "approved").length;
  const rejected = requests.filter(r => r.status === "rejected").length;

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;

  const filterTabs: { label: string; count: number; key: string | null }[] = [
    { label: "All", count: requests.length, key: null },
    { label: "Pending", count: pending, key: "pending" },
    { label: "Approved", count: approved, key: "approved" },
    { label: "Rejected", count: rejected, key: "rejected" },
  ];

  return (
    <>
      <div className="tabs" style={{ marginBottom: 12 }}>
        {filterTabs.map(t => (
          <button key={t.label} className={`tab ${filter === t.key ? "active" : ""}`} onClick={() => setFilter(t.key)}>
            {t.label} ({t.count})
          </button>
        ))}
      </div>
      {filtered.length === 0 ? (
        <p className="empty-text">No head change requests</p>
      ) : (
        <div className="activity-list">
          {filtered.map(r => (
            <div key={r.id} className="approval-card" style={{ marginBottom: 8, cursor: "pointer" }} onClick={() => setSelected(r)}>
              <div className="approval-top">
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <div style={{
                    width: 38, height: 38, borderRadius: 8,
                    background: "rgba(139,148,158,0.1)",
                    display: "flex", alignItems: "center", justifyContent: "center",
                  }}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#8b949e" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                      <circle cx="9" cy="7" r="4" />
                      <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                    </svg>
                  </div>
                  <div>
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <span style={{ fontSize: 18, color: "#8b949e", textDecoration: "line-through" }}>
                        {r.currentHeads}
                      </span>
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8b949e" strokeWidth="2">
                        <line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>
                      </svg>
                      <span style={{ fontSize: 20, fontWeight: 700 }}>
                        {r.requestedHeads}
                      </span>
                    </div>
                    <div style={{ fontSize: 12, color: "#8b949e" }}>
                      {r.currentHeads === 1 ? "head" : "heads"} → {r.requestedHeads === 1 ? "head" : "heads"}
                    </div>
                  </div>
                </div>
                {statusBadge(r.status)}
              </div>
              <div className="approval-details">
                <span>Requested {formatDate(r.requestedAt)}</span>
              </div>
              {r.processedAt && (
                <div className="approval-details">
                  <span>Processed {formatDate(r.processedAt)}</span>
                </div>
              )}
              {(r.reason || r.notes) && <p className="approval-notes">{r.reason || r.notes}</p>}
            </div>
          ))}
        </div>
      )}
      {selected && <HeadChangeDetailModal request={selected} onClose={() => setSelected(null)} />}
    </>
  );
};

/* Loan Request Modal */
const LoanRequestModal: React.FC<{ memberDocId: string | undefined; onClose: () => void }> = ({ memberDocId, onClose }) => {
  const [amount, setAmount] = useState("");
  const [notes, setNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!memberDocId || !amount) return;
    const amt = Number(amount);
    if (!Number.isFinite(amt) || amt <= 0) { alert("Amount must be greater than 0."); return; }
    setSubmitting(true);
    try {
      await addDoc(collection(db, "loan_requests"), {
        memberId: memberDocId,
        amount: amt,
        interestRate: 10,
        dueDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        status: "pending",
        requestedAt: Timestamp.now(),
        notes: notes.trim() || "",
      });
      onClose();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to submit");
    } finally { setSubmitting(false); }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Request Loan</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Amount (₱)</label>
            <input type="number" min="0" step="0.01" value={amount} onChange={e => setAmount(e.target.value)} required />
          </div>
          <div className="form-group">
            <label>Purpose (optional)</label>
            <input type="text" value={notes} onChange={e => setNotes(e.target.value)} />
          </div>
          <div className="form-hint" style={{ marginBottom: 16 }}>Interest rate: 10% • Due: 30 days</div>
          <div className="modal-actions">
            <button type="button" className="btn btn-outline" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? "Submitting..." : "Submit Request"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default Requests;
