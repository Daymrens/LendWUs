import React, { useEffect, useState } from "react";
import {
  collection,
  getDocs,
  query,
  orderBy,
  Timestamp,
} from "firebase/firestore";
import { db } from "../../firebase";

interface ActivityItem {
  id: string;
  type: string;
  description: string;
  amount?: string;
  status: string;
  date: Date;
  memberName?: string;
  details?: string;
}

const PAGE_SIZE = 30;

const Activity: React.FC = () => {
  const [allItems, setAllItems] = useState<ActivityItem[]>([]);
  const [filtered, setFiltered] = useState<ActivityItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [typeFilter, setTypeFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [page, setPage] = useState(0);

  useEffect(() => {
    loadActivity();
  }, []);

  useEffect(() => {
    let result = [...allItems];
    if (typeFilter !== "all") result = result.filter(a => a.type === typeFilter);
    if (statusFilter !== "all") result = result.filter(a => a.status === statusFilter);
    setFiltered(result);
    setPage(0);
  }, [allItems, typeFilter, statusFilter]);

  const loadActivity = async () => {
    setLoading(true);
    setError("");
    try {
      const [contSnap, loansSnap, paySnap, loanReqSnap, headSnap, membersSnap] = await Promise.all([
        getDocs(collection(db, "contributions")),
        getDocs(collection(db, "loans")),
        getDocs(query(collection(db, "payment_requests"), orderBy("requestDate", "desc"))),
        getDocs(query(collection(db, "loan_requests"), orderBy("requestedAt", "desc"))),
        getDocs(query(collection(db, "head_change_requests"), orderBy("requestedAt", "desc"))),
        getDocs(collection(db, "members")),
      ]);

      const names: Record<string, string> = {};
      membersSnap.docs.forEach(d => { names[d.id] = d.data().name || d.id; });

      const items: ActivityItem[] = [];

      contSnap.docs.forEach(d => {
        const c = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: "contribution",
          description: `Contribution by ${names[c.memberId as string] || c.memberId as string}`,
          amount: `₱${(Number(c.amount) || 0).toLocaleString()}`,
          status: (c.status as string) || "pending",
          date: (c.date as Timestamp)?.toDate?.() || new Date(),
          memberName: names[c.memberId as string],
        });
      });

      loansSnap.docs.forEach(d => {
        const l = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: "loan",
          description: `Loan issued to ${names[l.memberId as string] || l.memberId as string}`,
          amount: `₱${(Number(l.principal) || 0).toLocaleString()}`,
          status: l.isFullyRepaid ? "repaid" : "active",
          date: (l.issuedDate as Timestamp)?.toDate?.() || new Date(),
          memberName: names[l.memberId as string],
        });
      });

      paySnap.docs.forEach(d => {
        const p = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: p.type === "loan" ? "repayment" : "payment",
          description: p.type === "loan"
            ? `Loan repayment by ${names[p.memberId as string] || p.memberId as string}`
            : `Payment request from ${names[p.memberId as string] || p.memberId as string}`,
          amount: `₱${(Number(p.amount) || 0).toLocaleString()}`,
          status: (p.status as string) || "pending",
          date: (p.requestDate as Timestamp)?.toDate?.() || new Date(),
          memberName: names[p.memberId as string],
        });
      });

      loanReqSnap.docs.forEach(d => {
        const r = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: "loan_request",
          description: `Loan request from ${(r.memberName as string) || names[r.memberId as string] || r.memberId as string}`,
          amount: `₱${(Number(r.amount) || 0).toLocaleString()}`,
          status: (r.status as string) || "pending",
          date: (r.requestedAt as Timestamp)?.toDate?.() || new Date(),
          memberName: (r.memberName as string) || names[r.memberId as string],
        });
      });

      headSnap.docs.forEach(d => {
        const h = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: "head_change",
          description: `Head change request from ${(h.memberName as string) || names[h.memberId as string] || h.memberId as string}`,
          amount: `${h.currentHeads} → ${h.requestedHeads} heads`,
          status: (h.status as string) || "pending",
          date: (h.requestedAt as Timestamp)?.toDate?.() || new Date(),
          memberName: (h.memberName as string) || names[h.memberId as string],
          details: h.reason as string,
        });
      });

      items.sort((a, b) => b.date.getTime() - a.date.getTime());
      setAllItems(items);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load activity");
    } finally {
      setLoading(false);
    }
  };

  const paginated = filtered.slice(0, (page + 1) * PAGE_SIZE);
  const hasMore = paginated.length < filtered.length;

  const fmtStatus = (s: string) => {
    const m: Record<string, { label: string; cls: string }> = {
      approved: { label: "Approved", cls: "active-chip" },
      pending: { label: "Pending", cls: "badge-orange" },
      rejected: { label: "Rejected", cls: "inactive-chip" },
      repaid: { label: "Repaid", cls: "active-chip" },
      active: { label: "Active", cls: "badge-blue" },
    };
    return m[s] || { label: s, cls: "chip" };
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading activity...</p></div>;
  if (error) return <div className="admin-error"><p>{error}</p><button className="btn btn-primary" onClick={loadActivity}>Retry</button></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Activity Feed</h1>
        <button className="btn btn-outline btn-sm" onClick={loadActivity}>Refresh</button>
      </div>

      <div style={{ display: "flex", gap: 12, marginBottom: 16, flexWrap: "wrap" }}>
        <select className="search-input" style={{ width: "auto", marginBottom: 0 }} value={typeFilter} onChange={e => setTypeFilter(e.target.value)}>
          <option value="all">All Types</option>
          <option value="contribution">Contributions</option>
          <option value="loan">Loans</option>
          <option value="repayment">Repayments</option>
          <option value="payment">Payments</option>
          <option value="loan_request">Loan Requests</option>
          <option value="head_change">Head Changes</option>
        </select>
        <select className="search-input" style={{ width: "auto", marginBottom: 0 }} value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
          <option value="all">All Statuses</option>
          <option value="approved">Approved</option>
          <option value="pending">Pending</option>
          <option value="rejected">Rejected</option>
          <option value="repaid">Repaid</option>
          <option value="active">Active</option>
        </select>
        <span style={{ color: "#8b949e", fontSize: 13, alignSelf: "center" }}>{filtered.length} items</span>
      </div>

      <div className="activity-list">
        {paginated.length === 0 ? (
          <p className="empty-text">No activity found</p>
        ) : paginated.map(item => (
          <div key={`${item.type}-${item.id}`} className="activity-item">
            <div className={`activity-dot ${item.status === "approved" || item.status === "repaid" ? "success" : item.status === "pending" ? "pending" : "error"}`} />
            <div className="activity-info">
              <div className="activity-title">{item.description}</div>
              <div className="activity-sub">{item.date.toLocaleString()}{item.details ? ` • ${item.details}` : ""}</div>
            </div>
            <div style={{ textAlign: "right" }}>
              {item.amount && <div className={`activity-amount ${item.status === "approved" || item.status === "repaid" ? "text-success" : item.status === "pending" ? "text-pending" : "text-error"}`}>{item.amount}</div>}
              <div><span className={`chip ${fmtStatus(item.status).cls}`} style={{ fontSize: 10 }}>{fmtStatus(item.status).label}</span></div>
            </div>
          </div>
        ))}
      </div>

      {hasMore && (
        <div style={{ textAlign: "center", marginTop: 16 }}>
          <button className="btn btn-outline btn-sm" onClick={() => setPage(p => p + 1)}>Load More</button>
        </div>
      )}
    </div>
  );
};

export default Activity;
