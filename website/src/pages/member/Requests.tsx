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

      <div className="tabs" style={{ marginBottom: 16 }}>
        {(["payments", "loans", "heads"] as TabType[]).map(t => (
          <button key={t} className={`tab ${tab === t ? "active" : ""}`} onClick={() => setTab(t)}>
            {t.charAt(0).toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>

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

const statusBadge = (status: string) => {
  const map: Record<string, { color: string; bg: string }> = {
    pending: { color: "#f59e0b", bg: "rgba(245,158,11,0.15)" },
    approved: { color: "#22c55e", bg: "rgba(34,197,94,0.15)" },
    rejected: { color: "#ef4444", bg: "rgba(239,68,68,0.15)" },
    disbursed: { color: "#3b82f6", bg: "rgba(59,130,246,0.15)" },
  };
  const s = map[status] || map.pending;
  return (
    <span className="chip" style={{ background: s.bg, color: s.color, fontSize: 11 }}>
      {status.toUpperCase()}
    </span>
  );
};

const statusIcon = (status: string) => {
  switch (status) {
    case "pending": return "⏳";
    case "approved": return "✅";
    case "rejected": return "❌";
    case "disbursed": return "🏦";
    default: return "⏳";
  }
};

/* Detail Modal */
const PaymentDetailModal: React.FC<{ request: PaymentRequest; onClose: () => void }> = ({ request: r, onClose }) => {
  const statusColors: Record<string, { bg: string; color: string; icon: string; label: string }> = {
    pending: { bg: "rgba(245,158,11,0.15)", color: "#f59e0b", icon: "⏳", label: "Pending Review" },
    approved: { bg: "rgba(34,197,94,0.15)", color: "#22c55e", icon: "✅", label: "Approved" },
    rejected: { bg: "rgba(239,68,68,0.15)", color: "#ef4444", icon: "❌", label: "Rejected" },
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
          <div style={{ fontSize: 48, marginBottom: 8 }}>{sc.icon}</div>
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

  return (
    <>
      <div className="tabs" style={{ marginBottom: 12 }}>
        {[{ label: "All", count: requests.length, key: null },
          { label: "Pending", count: pending, key: "pending" },
          { label: "Approved", count: approved, key: "approved" },
          { label: "Rejected", count: rejected, key: "rejected" },
        ].map(t => (
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
                  <span style={{ fontSize: 20 }}>{statusIcon(r.status)}</span>
                  <span style={{ fontSize: 18, fontWeight: 700 }}>₱{formatCurrency(r.amount)}</span>
                </div>
                {statusBadge(r.status)}
              </div>
              <div className="approval-details">
                <span>Submitted {formatDate(r.requestDate)}</span>
                {r.type === "loan" && r.loanId && (
                  <span style={{ color: "#f59e0b", fontWeight: 600 }}>Loan repayment</span>
                )}
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
  const statusConfig: Record<string, { bg: string; color: string; icon: string; label: string }> = {
    pending: { bg: "rgba(245,158,11,0.15)", color: "#f59e0b", icon: "⏳", label: "Pending Review" },
    approved: { bg: "rgba(34,197,94,0.15)", color: "#22c55e", icon: "✅", label: "Approved" },
    rejected: { bg: "rgba(239,68,68,0.15)", color: "#ef4444", icon: "❌", label: "Rejected" },
    disbursed: { bg: "rgba(59,130,246,0.15)", color: "#3b82f6", icon: "🏦", label: "Disbursed" },
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
          <div style={{ fontSize: 48, marginBottom: 8 }}>{sc.icon}</div>
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

  return (
    <>
      <div className="tabs" style={{ marginBottom: 12, flexWrap: "wrap" }}>
        {[{ label: "All", count: requests.length, key: null },
          { label: "Pending", count: pending, key: "pending" },
          { label: "Approved", count: approved, key: "approved" },
          { label: "Rejected", count: rejected, key: "rejected" },
          { label: "Disbursed", count: disbursed, key: "disbursed" },
        ].map(t => (
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
                    <span style={{ fontSize: 20 }}>{statusIcon(r.status)}</span>
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
  const statusConfig: Record<string, { bg: string; color: string; icon: string; label: string }> = {
    pending: { bg: "rgba(245,158,11,0.15)", color: "#f59e0b", icon: "⏳", label: "Pending Review" },
    approved: { bg: "rgba(34,197,94,0.15)", color: "#22c55e", icon: "✅", label: "Approved" },
    rejected: { bg: "rgba(239,68,68,0.15)", color: "#ef4444", icon: "❌", label: "Rejected" },
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
          <div style={{ fontSize: 48, marginBottom: 8 }}>{sc.icon}</div>
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

  return (
    <>
      <div className="tabs" style={{ marginBottom: 12 }}>
        {[{ label: "All", count: requests.length, key: null },
          { label: "Pending", count: pending, key: "pending" },
          { label: "Approved", count: approved, key: "approved" },
          { label: "Rejected", count: rejected, key: "rejected" },
        ].map(t => (
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
                  <span style={{ fontSize: 20 }}>{statusIcon(r.status)}</span>
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
