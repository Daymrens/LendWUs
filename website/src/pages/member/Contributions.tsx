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

  useEffect(() => {
    if (!memberId) return;
    const unsubs: Array<() => void> = [];

    unsubs.push(onSnapshot(
      doc(db, "members", memberId),
      (snap) => {
        if (snap.exists()) {
          setMember({ id: snap.id, ...snap.data() } as MemberData);
        }
        setLoading(false);
      },
      (err) => { setError(err.message); setLoading(false); }
    ));

    return () => unsubs.forEach(u => u());
  }, [memberId]);

  useEffect(() => {
    if (!member?.id) return;
    const unsubs: Array<() => void> = [];

    unsubs.push(onSnapshot(
      query(collection(db, "contributions"), where("memberId", "==", member.id), orderBy("date", "desc")),
      (snap) => {
        setContributions(snap.docs.map(d => ({ id: d.id, ...d.data() } as Contribution)));
      }
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

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading contributions...</p></div>;
  if (error) return <div className="admin-error"><p>Error: {error}</p></div>;
  if (!member) return <div className="admin-loading"><p>Member profile not found.</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>My Contributions</h1>
      </div>

      <div className="section">
        <div className="chart-card">
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ margin: 0, color: "#c9d1d9", fontSize: 14, fontWeight: 600 }}>
              Total Contributions
            </h3>
            <span className="chip active-chip">{contributions.length} payments</span>
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: "#22c55e", marginBottom: 12 }}>
            ₱{formatCurrency(totalAll)}
          </div>
          {required > 0 && (
            <>
              <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
                <span style={{ fontSize: 13, fontWeight: 600, color: totalThisMonth >= required ? "#22c55e" : "#f59e0b" }}>
                  This month: ₱{formatCurrency(totalThisMonth)}
                </span>
                <span style={{ fontSize: 12, color: "#8b949e" }}>Required: ₱{formatCurrency(required)}</span>
              </div>
              <div style={{ height: 6, background: "#1c2128", borderRadius: 3, overflow: "hidden" }}>
                <div style={{ width: `${progress * 100}%`, height: "100%", background: totalThisMonth >= required ? "#22c55e" : "#f59e0b", borderRadius: 3 }} />
              </div>
            </>
          )}
          {member.balance > 0 && (
            <div style={{ marginTop: 12, fontSize: 13, color: "#22c55e", fontWeight: 600 }}>
              Credit balance: ₱{formatCurrency(member.balance)}
            </div>
          )}
        </div>
      </div>

      <div className="mini-stats">
        <div className="mini-stat accent">
          <span className="mini-stat-label">This Month</span>
          <span className="mini-stat-value">₱{formatCurrency(totalThisMonth)}</span>
        </div>
        <div className="mini-stat">
          <span className="mini-stat-label">Total</span>
          <span className="mini-stat-value">₱{formatCurrency(totalAll)}</span>
        </div>
        <div className="mini-stat">
          <span className="mini-stat-label">Last Month</span>
          <span className="mini-stat-value">₱{formatCurrency(totalLastMonth)}</span>
        </div>
        <div className="mini-stat">
          <span className="mini-stat-label">Avg/Payment</span>
          <span className="mini-stat-value">₱{formatCurrency(avg)}</span>
        </div>
      </div>

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
            return (
              <div key={key} className="approval-card" style={{ marginBottom: 12 }}>
                <div
                  className="approval-top"
                  style={{ cursor: "pointer", marginBottom: 0 }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <div
                      style={{
                        width: 36, height: 36, borderRadius: "50%",
                        background: "rgba(34,197,94,0.1)",
                        display: "flex", alignItems: "center", justifyContent: "center",
                        fontWeight: 700, fontSize: 13, color: "#22c55e",
                      }}
                    >
                      {parts[1]}
                    </div>
                    <strong>{monthName}</strong>
                  </div>
                  <span style={{ color: "#22c55e", fontWeight: 700, fontSize: 15 }}>
                    ₱{formatCurrency(monthTotal)}
                  </span>
                </div>
                <details style={{ marginTop: 8 }}>
                  <summary style={{ fontSize: 12, color: "#8b949e", cursor: "pointer", padding: "4px 0" }}>
                    {items.length} payment{items.length > 1 ? "s" : ""}
                  </summary>
                  <div style={{ marginTop: 8 }}>
                    {items.map(c => (
                      <div key={c.id} style={{
                        display: "flex", justifyContent: "space-between", alignItems: "center",
                        padding: "8px 0", borderBottom: "1px solid #21262d",
                      }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2"><polyline points="20 6 9 17 4 12"/></svg>
                          <span style={{ fontWeight: 600 }}>₱{formatCurrency(c.amount)}</span>
                        </div>
                        <span style={{ fontSize: 12, color: "#8b949e" }}>{formatDate(c.date)}</span>
                      </div>
                    ))}
                  </div>
                </details>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export default Contributions;
