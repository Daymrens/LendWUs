import React, { useEffect, useState, useMemo } from "react";
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
  receiptUrl?: string;
  notes?: string;
  rawStatus?: string;
}

interface GroupedItems {
  label: string;
  items: ActivityItem[];
}

const PAGE_SIZE = 30;

const TYPE_LABELS: Record<string, string> = {
  contribution: "Contribution",
  loan: "Loan Issuance",
  repayment: "Loan Repayment",
  payment: "Payment Request",
  loan_request: "Loan Request",
  head_change: "Head Change",
};

const TYPE_ICONS: Record<string, string> = {
  contribution: "💰",
  loan: "🏦",
  repayment: "💳",
  payment: "💵",
  loan_request: "📋",
  head_change: "👥",
};

function getRelativeTime(d: Date): string {
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "Yesterday";
  if (days < 7) return `${days}d ago`;
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function getGroupLabel(d: Date): string {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today.getTime() - 86400000);
  const weekStart = new Date(today.getTime() - today.getDay() * 86400000);
  const dDate = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  if (dDate.getTime() === today.getTime()) return "Today";
  if (dDate.getTime() === yesterday.getTime()) return "Yesterday";
  if (dDate >= weekStart) return "This Week";
  const month = d.toLocaleDateString("en-US", { month: "long", year: "numeric" });
  return month;
}

const formatDate = (d: Date) =>
  d.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });

const Activity: React.FC = () => {
  const [allItems, setAllItems] = useState<ActivityItem[]>([]);
  const [filtered, setFiltered] = useState<ActivityItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [typeFilter, setTypeFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(0);
  const [selected, setSelected] = useState<ActivityItem | null>(null);

  useEffect(() => {
    loadActivity();
  }, []);

  useEffect(() => {
    let result = [...allItems];
    if (typeFilter !== "all") result = result.filter(a => a.type === typeFilter);
    if (statusFilter !== "all") result = result.filter(a => a.status === statusFilter);
    if (search.trim()) {
      const q = search.toLowerCase();
      result = result.filter(a =>
        a.description.toLowerCase().includes(q) ||
        (a.memberName && a.memberName.toLowerCase().includes(q)) ||
        (a.details && a.details.toLowerCase().includes(q))
      );
    }
    setFiltered(result);
    setPage(0);
  }, [allItems, typeFilter, statusFilter, search]);

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
          description: `Contribution by ${names[c.memberId as string] || (c.memberId as string)}`,
          amount: `₱${(Number(c.amount) || 0).toLocaleString()}`,
          status: "approved",
          date: (c.date as Timestamp)?.toDate?.() || new Date(),
          memberName: names[c.memberId as string],
          receiptUrl: (c.receiptUrl as string) || undefined,
          notes: (c.notes as string) || undefined,
        });
      });

      loansSnap.docs.forEach(d => {
        const l = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: "loan",
          description: `Loan issued to ${names[l.memberId as string] || (l.memberId as string)}`,
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
            ? `Loan repayment by ${names[p.memberId as string] || (p.memberId as string)}`
            : `Payment request from ${names[p.memberId as string] || (p.memberId as string)}`,
          amount: `₱${(Number(p.amount) || 0).toLocaleString()}`,
          status: (p.status as string) || "pending",
          date: (p.requestDate as Timestamp)?.toDate?.() || new Date(),
          memberName: names[p.memberId as string],
          receiptUrl: (p.receiptUrl as string) || undefined,
          notes: (p.notes as string) || undefined,
          rawStatus: (p.status as string) || "pending",
        });
      });

      loanReqSnap.docs.forEach(d => {
        const r = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: "loan_request",
          description: `Loan request from ${(r.memberName as string) || names[r.memberId as string] || (r.memberId as string)}`,
          amount: `₱${(Number(r.amount) || 0).toLocaleString()}`,
          status: (r.status as string) || "pending",
          date: (r.requestedAt as Timestamp)?.toDate?.() || new Date(),
          memberName: (r.memberName as string) || names[r.memberId as string],
          notes: (r.notes as string) || undefined,
        });
      });

      headSnap.docs.forEach(d => {
        const h = d.data() as Record<string, unknown>;
        items.push({
          id: d.id,
          type: "head_change",
          description: `Head change request from ${(h.memberName as string) || names[h.memberId as string] || (h.memberId as string)}`,
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

  const groups = useMemo(() => {
    const map = new Map<string, ActivityItem[]>();
    for (const item of filtered) {
      const label = getGroupLabel(item.date);
      if (!map.has(label)) map.set(label, []);
      map.get(label)!.push(item);
    }
    const order = ["Today", "Yesterday", "This Week"];
    const result: GroupedItems[] = [];
    for (const key of order) {
      if (map.has(key)) { result.push({ label: key, items: map.get(key)! }); map.delete(key); }
    }
    map.forEach((items, label) => result.push({ label, items }));
    return result;
  }, [filtered]);

  const allGroups = useMemo(() => {
    let remaining = (page + 1) * PAGE_SIZE;
    const result: GroupedItems[] = [];
    for (const g of groups) {
      if (remaining <= 0) break;
      const take = Math.min(g.items.length, remaining);
      result.push({ label: g.label, items: g.items.slice(0, take) });
      remaining -= take;
    }
    return result;
  }, [groups, page]);

  const totalVisible = allGroups.reduce((s, g) => s + g.items.length, 0);
  const hasMore = totalVisible < filtered.length;

  const stats = useMemo(() => {
    const counts: Record<string, number> = {};
    for (const item of allItems) {
      counts[item.type] = (counts[item.type] || 0) + 1;
    }
    return counts;
  }, [allItems]);

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

  const statusColor = (s: string) => {
    if (s === "approved" || s === "repaid" || s === "disbursed") return "success";
    if (s === "pending") return "pending";
    if (s === "active") return "info";
    return "error";
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading activity...</p></div>;
  if (error) return <div className="admin-error"><p>{error}</p><button className="btn btn-primary" onClick={loadActivity}>Retry</button></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Activity Feed</h1>
        <button className="btn btn-outline btn-sm" onClick={loadActivity}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
          Refresh
        </button>
      </div>

      <div className="activity-toolbar">
        <div className="activity-filters">
          <select className="search-input" value={typeFilter} onChange={e => setTypeFilter(e.target.value)}>
            <option value="all">All Types</option>
            <option value="contribution">Contributions</option>
            <option value="loan">Loans</option>
            <option value="repayment">Repayments</option>
            <option value="payment">Payments</option>
            <option value="loan_request">Loan Requests</option>
            <option value="head_change">Head Changes</option>
          </select>
          <select className="search-input" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
            <option value="all">All Statuses</option>
            <option value="approved">Approved</option>
            <option value="pending">Pending</option>
            <option value="rejected">Rejected</option>
            <option value="repaid">Repaid</option>
            <option value="active">Active</option>
          </select>
          <div className="activity-search-wrapper">
            <svg className="activity-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input className="search-input activity-search" type="text" placeholder="Search activities..." value={search} onChange={e => setSearch(e.target.value)} />
          </div>
        </div>
        <span className="activity-count">{filtered.length} item{filtered.length !== 1 ? "s" : ""}</span>
      </div>

      <div className="activity-stats-bar">
        {Object.entries(stats).map(([type, count]) => (
          <div
            key={type}
            className={`activity-stat-chip ${typeFilter === type ? "active" : ""}`}
            onClick={() => setTypeFilter(typeFilter === type ? "all" : type)}
          >
            <span className="activity-stat-icon">{TYPE_ICONS[type] || "\u{1F4CB}"}</span>
            <span className="activity-stat-label">{type.replace("_", " ")}</span>
            <span className="activity-stat-count">{count}</span>
          </div>
        ))}
      </div>

      <div className="activity-feed">
        {allGroups.length === 0 ? (
          <p className="empty-text">No activity found</p>
        ) : allGroups.map(group => (
          <div key={group.label} className="activity-group">
            <div className="activity-group-header">
              <span className="activity-group-label">{group.label}</span>
              <span className="activity-group-line" />
            </div>
            {group.items.map(item => {
              const st = statusColor(item.status);
              return (
                <div
                  key={`${item.type}-${item.id}`}
                  className="activity-card"
                  onClick={() => setSelected(item)}
                  style={{ cursor: "pointer" }}
                >
                  <div className={`activity-card-icon activity-icon-${item.type}`}>
                    {TYPE_ICONS[item.type] || "\u{1F4CB}"}
                  </div>
                  <div className={`activity-card-dot activity-dot-${st}`} />
                  <div className="activity-card-body">
                    <div className="activity-card-title">{item.description}</div>
                    <div className="activity-card-meta">
                      <span>{getRelativeTime(item.date)}</span>
                      {item.details && <><span className="meta-sep">|</span><span>{item.details}</span></>}
                    </div>
                  </div>
                  <div className="activity-card-end">
                    {item.amount && (
                      <div className={`activity-card-amount activity-amount-${st}`}>
                        {item.amount}
                      </div>
                    )}
                    <span className={`chip ${fmtStatus(item.status).cls}`}>
                      {fmtStatus(item.status).label}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        ))}
      </div>

      {hasMore && (
        <div className="activity-load-more">
          <button className="btn btn-outline btn-sm" onClick={() => setPage(p => p + 1)}>
            Load More ({filtered.length - totalVisible} remaining)
          </button>
        </div>
      )}

      {selected && (
        <div className="modal-overlay" onClick={() => setSelected(null)}>
          <div className="modal-card" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
            <div className="modal-header">
              <h3>{TYPE_LABELS[selected.type] || "Transaction"} Details</h3>
              <button className="btn-icon" onClick={() => setSelected(null)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>
            <div className="modal-body">
              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                <DetailRow label="Type" value={TYPE_LABELS[selected.type] || selected.type} />
                <DetailRow label="Member" value={selected.memberName || "—"} />
                {selected.amount && <DetailRow label="Amount" value={selected.amount} />}
                <DetailRow label="Status" value={fmtStatus(selected.status).label} />
                <DetailRow label="Date" value={formatDate(selected.date)} />
                {selected.details && <DetailRow label="Details" value={selected.details} />}
                {selected.notes && <DetailRow label="Notes" value={selected.notes} />}
              </div>

              {selected.receiptUrl && (
                <>
                  <div style={{ height: 1, background: "#30363d", margin: "16px 0" }} />
                  <div>
                    <h4 style={{ color: "#e6edf3", margin: "0 0 8px", fontSize: 14 }}>Receipt</h4>
                    <img
                      src={selected.receiptUrl}
                      alt="Receipt"
                      style={{ maxWidth: "100%", maxHeight: "50vh", borderRadius: 8, objectFit: "contain" }}
                      onError={(e) => {
                        (e.target as HTMLImageElement).style.display = "none";
                      }}
                    />
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 8 }}>
      <span style={{ color: "#8b949e", fontSize: 13, minWidth: 70 }}>{label}</span>
      <span style={{ color: "#e6edf3", fontSize: 13, textAlign: "right", wordBreak: "break-word" }}>{value}</span>
    </div>
  );
}

export default Activity;
