import React, { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  doc,
  getDoc,
  updateDoc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useAuth } from "../../context/AuthContext";

interface PaymentRequest {
  id: string;
  memberId: string;
  type: "contribution" | "loan";
  amount: number;
  status: string;
  requestDate: string;
  bankConfirmed: boolean;
  bankConfirmedAt?: string;
  bankConfirmedBy?: string;
}

const CURRENCY_SYMBOL = "\u20B1";

const formatCurrency = (amount: number) => {
  return `${CURRENCY_SYMBOL}${amount.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`;
};

const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const [requests, setRequests] = useState<PaymentRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [memberNames, setMemberNames] = useState<Record<string, string>>({});
  const [confirmingId, setConfirmingId] = useState<string | null>(null);

  useEffect(() => {
    const q = query(
      collection(db, "payment_requests"),
      where("status", "==", "pending"),
      orderBy("requestDate", "desc")
    );

    const unsub = onSnapshot(q, (snapshot) => {
      const list = snapshot.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      })) as PaymentRequest[];
      setRequests(list);
      setLoading(false);

      // Fetch member names for all unique memberIds
      const memberIds = Array.from(new Set(list.map((r) => r.memberId)));
      memberIds.forEach(async (mid) => {
        if (memberNames[mid]) return;
        try {
          const snap = await getDoc(doc(db, "members", mid));
          if (snap.exists()) {
            setMemberNames((prev) => ({ ...prev, [mid]: snap.data().name || "Unknown" }));
          }
        } catch {
          setMemberNames((prev) => ({ ...prev, [mid]: "Unknown" }));
        }
      });
    });

    return () => unsub();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleConfirmBankReceived = async (request: PaymentRequest) => {
    const confirmed = window.confirm(
      `Have you received ${formatCurrency(request.amount)} from the member for this ${request.type} request?\n\nThe admin will be notified.`
    );
    if (!confirmed || !user) return;

    setConfirmingId(request.id);
    try {
      await updateDoc(doc(db, "payment_requests", request.id), {
        bankConfirmed: true,
        bankConfirmedAt: serverTimestamp(),
        bankConfirmedBy: user.uid,
      });
      alert("Bank receipt confirmed. Admin has been notified.");
    } catch (err) {
      console.error("Failed to confirm bank receipt:", err);
      alert("Failed to confirm. Please try again.");
    } finally {
      setConfirmingId(null);
    }
  };

  const timeAgo = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const hours = Math.floor(diffMs / (1000 * 60 * 60));
    if (hours < 1) return "Just now";
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  };

  const pending = requests.filter((r) => !r.bankConfirmed);
  const confirmed = requests.filter((r) => r.bankConfirmed);

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Treasurer Dashboard</h1>
        <span className="badge badge-primary">{requests.length} pending</span>
      </div>

      <div className="stats-grid" style={{ gridTemplateColumns: "repeat(3, 1fr)", marginBottom: 24 }}>
        <div className="stat-card">
          <div className="stat-value" style={{ color: "#f59e0b" }}>{pending.length}</div>
          <div className="stat-label">Awaiting Confirmation</div>
        </div>
        <div className="stat-card">
          <div className="stat-value" style={{ color: "#10b981" }}>{confirmed.length}</div>
          <div className="stat-label">Confirmed</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{requests.length}</div>
          <div className="stat-label">Total Pending</div>
        </div>
      </div>

      {loading ? (
        <div className="admin-loading">
          <div className="spinner" />
          <p>Loading payment requests...</p>
        </div>
      ) : (
        <>
          <h2 style={{ marginBottom: 12, display: "flex", alignItems: "center", gap: 8 }}>
            <span style={{ display: "inline-block", width: 4, height: 20, background: "#f59e0b", borderRadius: 2 }} />
            Pending Bank Confirmation
            <span className="badge badge-warning">{pending.length}</span>
          </h2>

          {pending.length === 0 ? (
            <div className="empty-state" style={{ textAlign: "center", padding: 40, color: "#6b7280" }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>{"\u2705"}</div>
              <p>All payments have been confirmed.</p>
            </div>
          ) : (
            <div className="approvals-list">
              {pending.map((req) => (
                <div key={req.id} className="approval-card">
                  <div className="approval-card-header">
                    <div className="approval-user-info">
                      <div className="approval-avatar">
                        {memberNames[req.memberId]?.charAt(0)?.toUpperCase() || "?"}
                      </div>
                      <div>
                        <div className="approval-name">{memberNames[req.memberId] || "Loading..."}</div>
                        <div className="approval-detail">
                          {req.type === "contribution" ? "Contribution" : "Loan Repayment"}
                          {" \u00B7 "}
                          {timeAgo(req.requestDate)}
                        </div>
                      </div>
                    </div>
                    <div className="approval-amount">{formatCurrency(req.amount)}</div>
                  </div>
                  <div className="approval-actions">
                    <button
                      className="btn btn-success btn-sm"
                      onClick={() => handleConfirmBankReceived(req)}
                      disabled={confirmingId === req.id}
                      style={{ flex: 1 }}
                    >
                      {confirmingId === req.id ? "Confirming..." : "Confirm Bank Received"}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

          <h2 style={{ margin: "24px 0 12px", display: "flex", alignItems: "center", gap: 8 }}>
            <span style={{ display: "inline-block", width: 4, height: 20, background: "#10b981", borderRadius: 2 }} />
            Confirmed (Awaiting Admin Approval)
            <span className="badge badge-success">{confirmed.length}</span>
          </h2>

          {confirmed.length === 0 ? (
            <div className="empty-state" style={{ textAlign: "center", padding: 40, color: "#6b7280" }}>
              <p>No confirmed payments yet.</p>
            </div>
          ) : (
            <div className="approvals-list">
              {confirmed.map((req) => (
                <div key={req.id} className="approval-card">
                  <div className="approval-card-header">
                    <div className="approval-user-info">
                      <div className="approval-avatar">
                        {memberNames[req.memberId]?.charAt(0)?.toUpperCase() || "?"}
                      </div>
                      <div>
                        <div className="approval-name">{memberNames[req.memberId] || "Loading..."}</div>
                        <div className="approval-detail">
                          {req.type === "contribution" ? "Contribution" : "Loan Repayment"}
                          {" \u00B7 "}
                          {timeAgo(req.requestDate)}
                        </div>
                      </div>
                    </div>
                    <div className="approval-amount">{formatCurrency(req.amount)}</div>
                  </div>
                  <div className="approval-status-confirmed">
                    {"\u2705"} Confirmed bank receipt
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
};

export default Dashboard;
