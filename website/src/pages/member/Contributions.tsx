import React, { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  Timestamp,
  doc,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from "recharts";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

interface Contribution {
  id: string;
  memberId: string;
  amount: number;
  date: Timestamp;
  month: number;
  year: number;
  notes?: string;
}

interface MemberData {
  id: string;
  memberId: string;
  name: string;
  headsCount: number;
  amountPerHead: number;
  totalRequired: number;
  balance: number;
}

const Contributions: React.FC = () => {
  const { user } = useMemberAuth();
  const memberId = user?.memberId;

  const [member, setMember] = useState<MemberData | null>(null);
  const [contributions, setContributions] = useState<Contribution[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [expandedMonths, setExpandedMonths] = useState<Record<string, boolean>>({});

  useEffect(() => {
    if (!memberId) return;
    console.log("[Contributions] memberId:", memberId);
    const unsubs: Array<() => void> = [];

    unsubs.push(onSnapshot(
      doc(db, "members", memberId),
      (snap) => {
        if (snap.exists()) {
          const data = snap.data() as Record<string, unknown>;
          console.log("[Contributions] member doc loaded, id:", snap.id, "memberId field:", data.memberId);
          setMember({ id: snap.id, ...snap.data() } as MemberData);
        } else {
          console.error("[Contributions] member doc NOT FOUND");
        }
        setLoading(false);
      },
      (err) => { console.error("[Contributions] member doc error:", err); setError(err.message); setLoading(false); }
    ));

    return () => unsubs.forEach(u => u());
  }, [memberId]);

  useEffect(() => {
    if (!member?.id) return;
    console.log("[Contributions] querying contributions for:", member.id);
    const unsubs: Array<() => void> = [];

    unsubs.push(onSnapshot(
      query(collection(db, "contributions"), where("memberId", "==", member.id), orderBy("date", "desc")),
      (snap) => {
        console.log("[Contributions] contributions count:", snap.docs.length);
        setContributions(snap.docs.map(d => ({ id: d.id, ...d.data() } as Contribution)));
      },
      (err) => { console.error("[Contributions] contributions error:", err); }
    ));

    return () => unsubs.forEach(u => u());
  }, [member?.id]);

  const now = new Date();
  const totalAll = contributions.reduce((s, c) => s + (Number(c.amount) || 0), 0);
  const thisMonth = contributions.filter(c => {
    const d = c.date?.toDate?.();
    return d && d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
  });
  const totalThisMonth = thisMonth.reduce((s, c) => s + (Number(c.amount) || 0), 0);
  const lastMonth = contributions.filter(c => {
    const d = c.date?.toDate?.();
    const lm = new Date(now.getFullYear(), now.getMonth() - 1);
    return d && d.getMonth() === lm.getMonth() && d.getFullYear() === lm.getFullYear();
  });
  const totalLastMonth = lastMonth.reduce((s, c) => s + (Number(c.amount) || 0), 0);
  const required = member?.totalRequired || 0;
  const progress = required > 0 ? Math.min(totalThisMonth / required, 1) : 0;
  const avg = contributions.length > 0 ? totalAll / contributions.length : 0;

  const monthlyMap: Record<string, number> = {};
  for (let i = 5; i >= 0; i--) {
    const d = new Date(); d.setMonth(d.getMonth() - i);
    monthlyMap[`${MONTHS[d.getMonth()]} ${d.getFullYear()}`] = 0;
  }
  contributions.forEach(c => {
    const cd = c.date?.toDate?.();
    if (cd) {
      const key = `${MONTHS[cd.getMonth()]} ${cd.getFullYear()}`;
      if (monthlyMap[key] !== undefined) monthlyMap[key] += Number(c.amount) || 0;
    }
  });
  const monthlyData = Object.entries(monthlyMap).map(([month, amount]) => ({ month, amount }));

  const grouped: Record<string, Contribution[]> = {};
  contributions.forEach(c => {
    const d = c.date?.toDate?.();
    if (d) {
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(c);
    }
  });
  const sortedKeys = Object.keys(grouped).sort((a, b) => b.localeCompare(a));

  const formatCurrency = (n: number) =>
    n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  const formatDate = (ts: Timestamp) => {
    if (!ts?.toDate) return "N/A";
    const d = ts.toDate();
    const diff = Math.floor((Date.now() - d.getTime()) / (1000 * 60 * 60 * 24));
    if (diff === 0) return "Today";
    if (diff === 1) return "Yesterday";
    if (diff < 7) return `${diff}d ago`;
    return d.toLocaleDateString();
  };

  const toggleMonth = (key: string) => {
    setExpandedMonths(prev => ({ ...prev, [key]: !prev[key] }));
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading contributions...</p></div>;
  if (error) return <div className="admin-error"><p>Error: {error}</p></div>;
  if (!member) return <div className="admin-loading"><p>Member profile not found.</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>My Contributions</h1>
      </div>

      <div className="reports-summary">
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(34,197,94,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 1v22"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">This Month</span>
            <span className="report-summary-value text-success">₱{formatCurrency(totalThisMonth)}</span>
            {required > 0 && (
              <span className="report-summary-sub">
                {progress >= 1 ? "Fully paid" : `${(progress * 100).toFixed(0)}% of ₱${formatCurrency(required)}`}
              </span>
            )}
          </div>
        </div>
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(59,130,246,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#3b82f6" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">Total All Time</span>
            <span className="report-summary-value">₱{formatCurrency(totalAll)}</span>
            <span className="report-summary-sub">{contributions.length} payments</span>
          </div>
        </div>
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(245,158,11,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">Last Month</span>
            <span className="report-summary-value text-pending">₱{formatCurrency(totalLastMonth)}</span>
          </div>
        </div>
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(139,148,158,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#8b949e" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M10 2L2 10v2l10 10 10-10V10L14 2z"/><path d="M12 8v4"/><path d="M12 16h0"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">Avg / Payment</span>
            <span className="report-summary-value">₱{formatCurrency(avg)}</span>
            <span className="report-summary-sub">Across all contributions</span>
          </div>
        </div>
      </div>

      {member.balance > 0 && (
        <div className="section">
          <div className="chart-card" style={{ borderColor: "#22c55e33", background: "linear-gradient(135deg, #161b22, #0d2818)" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/></svg>
              <span style={{ color: "#22c55e", fontSize: 14, fontWeight: 600 }}>Credit Balance</span>
              <span style={{ marginLeft: "auto", color: "#22c55e", fontSize: 20, fontWeight: 800 }}>₱{formatCurrency(member.balance)}</span>
            </div>
          </div>
        </div>
      )}

      <div className="section">
        <h2>Monthly Trend (6 months)</h2>
        <div className="chart-card">
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={monthlyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#21262d" />
              <XAxis dataKey="month" stroke="#8b949e" fontSize={11} />
              <YAxis stroke="#8b949e" fontSize={11} />
              <Tooltip contentStyle={{ background: "#161b22", border: "1px solid #30363d", borderRadius: 8, fontSize: 13 }} />
              <Bar dataKey="amount" name="Contributions" fill="#22c55e" radius={[4,4,0,0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="section">
        <h2>All Contributions</h2>
        {contributions.length === 0 ? (
          <p className="empty-text">No contributions yet</p>
        ) : (
          sortedKeys.map(key => {
            const items = grouped[key];
            const monthTotal = items.reduce((s, c) => s + (Number(c.amount) || 0), 0);
            const parts = key.split("-");
            const monthName = `${MONTHS[parseInt(parts[1]) - 1]} ${parts[0]}`;
            const monthProgress = required > 0 ? Math.min(monthTotal / required, 1) : 0;
            const isExpanded = expandedMonths[key] ?? false;
            const isCurrentMonth =
              parseInt(parts[0]) === now.getFullYear() && parseInt(parts[1]) === now.getMonth() + 1;

            return (
              <div key={key} className="approval-card" style={{ marginBottom: 12, overflow: "hidden" }}>
                <div
                  className="approval-top"
                  style={{ cursor: "pointer", marginBottom: 0 }}
                  onClick={() => toggleMonth(key)}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <div style={{
                      width: 38, height: 38, borderRadius: "50%",
                      background: isCurrentMonth ? "rgba(34,197,94,0.15)" : "rgba(139,148,158,0.1)",
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontWeight: 700, fontSize: 14, color: isCurrentMonth ? "#22c55e" : "#8b949e",
                      flexShrink: 0,
                    }}>
                      {parts[1]}
                    </div>
                    <div>
                      <strong style={{ color: "#e6edf3", fontSize: 15, fontWeight: 600 }}>{monthName}</strong>
                      <div style={{ fontSize: 11, color: "#8b949e", marginTop: 2 }}>
                        {items.length} payment{items.length > 1 ? "s" : ""}
                        {isCurrentMonth && <span className="chip active-chip" style={{ marginLeft: 8, fontSize: 9 }}>Current</span>}
                      </div>
                    </div>
                  </div>
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <div style={{ textAlign: "right" }}>
                      <span style={{ color: "#22c55e", fontWeight: 700, fontSize: 16, display: "block" }}>
                        ₱{formatCurrency(monthTotal)}
                      </span>
                      {required > 0 && (
                        <span style={{ fontSize: 11, color: "#8b949e" }}>
                          {monthProgress >= 1 ? "✓ Complete" : `${(monthProgress * 100).toFixed(0)}%`}
                        </span>
                      )}
                    </div>
                    <svg
                      width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8b949e" strokeWidth="2"
                      style={{ transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)", transition: "transform 0.2s", flexShrink: 0 }}
                    >
                      <polyline points="6 9 12 15 18 9"/>
                    </svg>
                  </div>
                </div>

                {required > 0 && (
                  <div style={{ marginTop: 10, marginBottom: isExpanded ? 12 : 0 }}>
                    <div style={{ height: 4, background: "#1c2128", borderRadius: 2, overflow: "hidden" }}>
                      <div style={{
                        width: `${monthProgress * 100}%`, height: "100%",
                        background: monthProgress >= 1 ? "#22c55e" : monthProgress >= 0.5 ? "#f59e0b" : "#ef4444",
                        borderRadius: 2, transition: "width 0.4s",
                      }} />
                    </div>
                  </div>
                )}

                {isExpanded && (
                  <div style={{ marginTop: 4, borderTop: "1px solid #21262d", paddingTop: 8 }}>
                    {items.map(c => (
                      <div key={c.id} style={{
                        display: "flex", justifyContent: "space-between", alignItems: "center",
                        padding: "8px 0", borderBottom: "1px solid #21262d",
                      }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                          <div style={{
                            width: 24, height: 24, borderRadius: "50%",
                            background: "rgba(34,197,94,0.1)",
                            display: "flex", alignItems: "center", justifyContent: "center",
                          }}>
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2"><polyline points="20 6 9 17 4 12"/></svg>
                          </div>
                          <span style={{ fontWeight: 600, color: "#e6edf3" }}>₱{formatCurrency(c.amount)}</span>
                        </div>
                        <span style={{ fontSize: 12, color: "#8b949e" }}>{formatDate(c.date)}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export default Contributions;
