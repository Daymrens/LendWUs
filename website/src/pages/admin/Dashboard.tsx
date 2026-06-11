import React, { useEffect, useMemo, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  limit,
  addDoc,
  onSnapshot,
  Timestamp,
} from "firebase/firestore";
import { db } from "../../firebase";
import { downloadCSV } from "../../utils/export";
import { backfillMissingMemberIds } from "../../utils/memberId";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend,
} from "recharts";

const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

interface RawDoc { id: string; [k: string]: unknown }
interface DashboardData {
  totalMembers: number; activeMembers: number;
  totalContributions: number; totalLoansIssued: number;
  activeLoans: number; overdueLoans: number;
  fundBalance: number; totalInterest: number;
  pendingPayments: number; pendingLoans: number; pendingHeads: number;
  recentActivity: Array<{ type: string; description: string; amount: string; time: string; status: string }>;
  monthlyData: Array<{ month: string; contributions: number; loans: number; repayments: number }>;
  loanStatusData: Array<{ name: string; value: number }>;
  topMembers: Array<{ name: string; contributions: number; loans: number }>;
  memberNames: Record<string, string>;
  annualReturns: number;
  annualContributions: number;
  annualLoans: number;
  annualRepayments: number;
  totalHeads: number;
  perHeadShare: number;
  fundUtilization: number;
  collectionRate: number;
  monthlyContributionsCurrent: number;
  monthlyRequiredCurrent: number;
  avgContributionPerMember: number;
}

const COLORS = ["#22c55e", "#f59e0b", "#ef4444", "#3b82f6", "#8b5cf6", "#ec4899"];

const Dashboard: React.FC = () => {
  const [members, setMembers] = useState<RawDoc[]>([]);
  const [contributions, setContributions] = useState<RawDoc[]>([]);
  const [loans, setLoans] = useState<RawDoc[]>([]);
  const [payments, setPayments] = useState<RawDoc[]>([]);
  const [loanReqs, setLoanReqs] = useState<RawDoc[]>([]);
  const [heads, setHeads] = useState<RawDoc[]>([]);
  const [repayments, setRepayments] = useState<RawDoc[]>([]);
  const [repaymentsData, setRepaymentsData] = useState<RawDoc[]>([]);
  const [recentContribs, setRecentContribs] = useState<RawDoc[]>([]);
  const [recentPayments, setRecentPayments] = useState<RawDoc[]>([]);
  const [firstLoad, setFirstLoad] = useState(true);
  const [error, setError] = useState("");
  const [chartTab, setChartTab] = useState(0);
  const [actionModal, setActionModal] = useState<string | null>(null);
  const [actionMsg, setActionMsg] = useState("");

  useEffect(() => {
    const unsubs: Array<() => void> = [];
    const attach = <T,>(setter: (v: T) => void, q: ReturnType<typeof query>) => {
      unsubs.push(onSnapshot(q, (snap) => {
        setter(snap.docs.map(d => ({ id: d.id, ...(d.data() as Record<string, unknown>) })) as unknown as T);
        setFirstLoad(false);
      }, (err) => { setError(err.message); setFirstLoad(false); }));
    };

    attach<RawDoc[]>(setMembers, collection(db, "members"));
    attach<RawDoc[]>(setContributions, collection(db, "contributions"));
    attach<RawDoc[]>(setLoans, collection(db, "loans"));
    attach<RawDoc[]>(setPayments, collection(db, "payment_requests"));
    attach<RawDoc[]>(setLoanReqs, collection(db, "loan_requests"));
    attach<RawDoc[]>(setHeads, collection(db, "head_change_requests"));
    attach<RawDoc[]>(setRepayments, query(collection(db, "payment_requests"), where("type","==","loan"), where("status","==","approved")));
    attach<RawDoc[]>(setRepaymentsData, collection(db, "repayments"));
    attach<RawDoc[]>(setRecentContribs, query(collection(db, "contributions"), orderBy("date","desc"), limit(10)));
    attach<RawDoc[]>(setRecentPayments, query(collection(db, "payment_requests"), orderBy("requestDate","desc"), limit(10)));

    return () => unsubs.forEach(u => u());
  }, []);

  const data: DashboardData | null = useMemo(() => {
    if (firstLoad) return null;
    const memberNames: Record<string, string> = {};
    members.forEach((m) => { memberNames[m.id] = (m.name as string) || m.id; });

    const totalMembers = members.length;
    const activeMembers = members.filter((m) => m.isActive === true || m.isActive === 1).length;
    const totalContributions = contributions.reduce((s, c) => s + (Number(c.amount)||0), 0);
    const totalLoansIssued = loans.reduce((s, l) => s + (Number(l.principal)||0), 0);
    const activeLoans = loans.filter((l) => l.isFullyRepaid !== true && l.isFullyRepaid !== 1).length;
    const now = new Date();
    const overdueLoans = loans.filter((l) => {
      if (l.isFullyRepaid === true || l.isFullyRepaid === 1) return false;
      const dd = (l.dueDate as Timestamp)?.toDate ? (l.dueDate as Timestamp).toDate() : new Date(String(l.dueDate));
      return dd < now;
    }).length;

    const pendingPayments = payments.filter((p) => p.status === "pending").length;
    const pendingLoans = loanReqs.filter((r) => r.status === "pending").length;
    const pendingHeads = heads.filter((r) => r.status === "pending").length;

    const totalRepayments = repayments.reduce((s, r) => s + (Number(r.amount)||0), 0);
    const fundBalance = totalContributions - totalLoansIssued + totalRepayments;

    const loanRepaymentMap: Record<string, number> = {};
    repaymentsData.forEach((r) => {
      const lid = r.loanId as string;
      if (lid) loanRepaymentMap[lid] = (loanRepaymentMap[lid] || 0) + (Number(r.amountPaid) || 0);
    });
    const totalInterest = loans.reduce((s, l) => {
      const repaid = loanRepaymentMap[l.id] || 0;
      const interest = repaid - (Number(l.principal) || 0);
      return s + (interest > 0 ? interest : 0);
    }, 0);

    const activeMembersList = members.filter((m) => m.isActive === true || m.isActive === 1);
    const totalHeads = activeMembersList.reduce((s, m) => s + (Number(m.headsCount) || 1), 0);
    const perHeadShare = totalHeads > 0 ? totalInterest / totalHeads : 0;

    const fundUtilization = totalContributions > 0 ? ((totalLoansIssued - totalRepayments) / totalContributions) * 100 : 0;

    const thisMonth = now.getMonth() + 1;
    const thisYear = now.getFullYear();
    const monthlyContributionsCurrent = contributions
      .filter((c) => {
        const d = (c.date as Timestamp)?.toDate?.();
        return d && d.getMonth() + 1 === thisMonth && d.getFullYear() === thisYear;
      })
      .reduce((s, c) => s + (Number(c.amount)||0), 0);
    const monthlyRequiredCurrent = activeMembersList.reduce((s, m) => s + (Number(m.amountPerHead) || Number(m.headsCount) * 500 || 500), 0);
    const collectionRate = monthlyRequiredCurrent > 0 ? (monthlyContributionsCurrent / monthlyRequiredCurrent) * 100 : 0;
    const avgContributionPerMember = activeMembers > 0 ? totalContributions / activeMembers : 0;

    const recentActivity = [
      ...recentContribs.map((r) => {
        const cd = r.date as Timestamp | undefined;
        return { type: "Contribution", description: "Direct contribution", amount: `₱${(Number(r.amount)||0).toLocaleString()}`, time: cd?.toDate?.()?.toLocaleDateString() || "", status: "approved" as const };
      }),
      ...recentPayments.map((r) => {
        const rd = r.requestDate as Timestamp | undefined;
        return { type: r.type === "loan" ? "Loan Repayment" : "Contribution", description: `${r.type === "loan" ? "Loan repayment" : "Contribution"}`, amount: `₱${(Number(r.amount)||0).toLocaleString()}`, time: rd?.toDate?.()?.toLocaleDateString() || "", status: ((r.status as string)||"pending") as "approved" | "pending" | "rejected" };
      }),
    ].sort((a,b) => (a.time < b.time ? 1 : -1)).slice(0, 10);

    const monthlyMap: Record<string, { contributions: number; loans: number; repayments: number }> = {};
    for (let i = 5; i >= 0; i--) {
      const d = new Date(); d.setMonth(d.getMonth() - i);
      const key = `${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
      monthlyMap[key] = { contributions: 0, loans: 0, repayments: 0 };
    }
    contributions.forEach((c) => {
      const cd = (c.date as Timestamp)?.toDate ? (c.date as Timestamp).toDate() : new Date(String(c.date));
      const key = `${MONTHS[cd.getMonth()]} ${cd.getFullYear()}`;
      if (monthlyMap[key]) monthlyMap[key].contributions += Number(c.amount)||0;
    });
    loans.forEach((l) => {
      const ld = (l.issuedDate as Timestamp)?.toDate ? (l.issuedDate as Timestamp).toDate() : new Date(String(l.issuedDate));
      const key = `${MONTHS[ld.getMonth()]} ${ld.getFullYear()}`;
      if (monthlyMap[key]) monthlyMap[key].loans += Number(l.principal)||0;
    });
    payments.filter((p) => p.type === "loan" && p.status === "approved").forEach((p) => {
      const pd = (p.approvedDate as Timestamp)?.toDate ? (p.approvedDate as Timestamp).toDate() : new Date(String(p.requestDate));
      const key = `${MONTHS[pd.getMonth()]} ${pd.getFullYear()}`;
      if (monthlyMap[key]) monthlyMap[key].repayments += Number(p.amount)||0;
    });
    const monthlyData = Object.entries(monthlyMap).map(([month, v]) => ({ month, ...v }));

    const approved = payments.filter((p) => p.status === "approved").length;
    const rejected = payments.filter((p) => p.status === "rejected").length;
    const pendCount = payments.filter((p) => p.status === "pending").length;
    const loanApproved = loans.length;
    const loanStatusData = [
      { name: "Approved", value: approved+loanApproved }, { name: "Pending", value: pendCount+pendingLoans+pendingHeads },
      { name: "Overdue", value: overdueLoans }, { name: "Rejected", value: rejected },
    ];

    const memberContribs: Record<string, { contribs: number; loans_: number }> = {};
    members.forEach((m) => { memberContribs[m.id] = { contribs: 0, loans_: 0 }; });
    contributions.forEach((c) => {
      const mid = c.memberId as string;
      if (memberContribs[mid]) memberContribs[mid].contribs += Number(c.amount)||0;
    });
    loans.forEach((l) => {
      const mid = l.memberId as string;
      if (memberContribs[mid]) memberContribs[mid].loans_ += Number(l.principal)||0;
    });
    const topMembers = Object.entries(memberContribs)
      .map(([id, v]) => ({ name: memberNames[id]||id, contributions: v.contribs, loans: v.loans_ }))
      .sort((a,b) => b.contributions - a.contributions).slice(0, 5);

    const annualContributions = contributions
      .filter((c) => { const d = (c.date as Timestamp)?.toDate?.(); return d && d.getFullYear() === thisYear; })
      .reduce((s, c) => s + (Number(c.amount)||0), 0);
    const annualLoans = loans
      .filter((l) => { const d = (l.issuedDate as Timestamp)?.toDate?.(); return d && d.getFullYear() === thisYear; })
      .reduce((s, l) => s + (Number(l.principal)||0), 0);
    const annualRepayments = payments
      .filter((p) => { const d = (p.approvedDate as Timestamp)?.toDate?.() || (p.requestDate as Timestamp)?.toDate?.(); return d && d.getFullYear() === thisYear && p.status === "approved" && p.type === "loan"; })
      .reduce((s, p) => s + (Number(p.amount)||0), 0);
    const annualReturns = annualRepayments - annualLoans + annualContributions;

    return { totalMembers, activeMembers, totalContributions, totalLoansIssued, activeLoans, overdueLoans, fundBalance, totalInterest, pendingPayments, pendingLoans, pendingHeads, recentActivity, monthlyData, loanStatusData, topMembers, memberNames, annualReturns, annualContributions, annualLoans, annualRepayments, totalHeads, perHeadShare, fundUtilization, collectionRate, monthlyContributionsCurrent, monthlyRequiredCurrent, avgContributionPerMember };
  }, [firstLoad, members, contributions, loans, payments, loanReqs, heads, repayments, repaymentsData, recentContribs, recentPayments]);

  const refresh = () => setFirstLoad((v) => v);

  const handleBackfill = async () => {
    if (!window.confirm("This will generate formatted IDs (LWS000000) for all members missing them, ordered by join date. Proceed?")) return;
    try {
      const count = await backfillMissingMemberIds(db);
      alert(`Successfully backfilled ${count} members.`);
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Backfill failed");
    }
  };

  const exportDashboard = () => {
    if (!data) return;
    downloadCSV([
      { metric: "Total Fund", value: data.totalContributions + data.totalInterest },
      { metric: "Active Members", value: data.activeMembers },
      { metric: "Total Members", value: data.totalMembers },
      { metric: "Total Contributions", value: data.totalContributions },
      { metric: "Total Loans Issued", value: data.totalLoansIssued },
      { metric: "Active Loans", value: data.activeLoans },
      { metric: "Overdue Loans", value: data.overdueLoans },
      { metric: "Total Interest", value: data.totalInterest },
      { metric: "Pending Approvals", value: data.pendingPayments + data.pendingLoans + data.pendingHeads },
      { metric: "Annual Returns", value: data.annualReturns },
      { metric: "Per-Head Share", value: data.perHeadShare },
      { metric: "Fund Utilization", value: `${data.fundUtilization.toFixed(1)}%` },
    ], "dashboard_summary");
  };

  const handleQuickAction = async (type: string, formData: Record<string, unknown>) => {
    try {
      const now = Timestamp.now();
      const d = now.toDate();
      if (type === "contribution") {
        const payload: Record<string, unknown> = { ...formData };
        payload.date = now;
        payload.month = d.getMonth() + 1;
        payload.year = d.getFullYear();
        payload.status = "approved";
        payload.createdBy = "admin";
        if (payload.notes === undefined || payload.notes === "") delete payload.notes;
        await addDoc(collection(db, "contributions"), payload);
        await addDoc(collection(db, "payment_requests"), {
          memberId: formData.memberId,
          amount: formData.amount,
          type: "contribution",
          status: "approved",
          requestDate: now,
          approvedDate: now,
          approvedBy: "Admin (Manual)",
          notes: formData.notes || "Manual contribution",
        });
      } else if (type === "loan") {
        const payload: Record<string, unknown> = { ...formData };
        payload.issuedDate = now;
        payload.isFullyRepaid = false;
        payload.status = "active";
        if (payload.notes === undefined || payload.notes === "") delete payload.notes;
        await addDoc(collection(db, "loans"), payload);
      } else {
        const payload: Record<string, unknown> = { ...formData };
        payload.requestDate = now;
        payload.status = "pending";
        payload.type = "loan";
        await addDoc(collection(db, "payment_requests"), payload);
      }
      setActionModal(null);
      const labels: Record<string, string> = { contribution: "Contribution", loan: "Loan", repayment: "Repayment" };
      setActionMsg(`${labels[type] || "Record"} saved successfully.`);
      setTimeout(() => setActionMsg(""), 3000);
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed");
    }
  };

  if (firstLoad) return <div className="admin-loading"><div className="spinner" /><p>Loading dashboard...</p></div>;
  if (error) return <div className="admin-error"><p>Error: {error}</p><button className="btn btn-primary" onClick={refresh}>Retry</button></div>;
  if (!data) return null;

  const fmt = (n: number) => n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const totalPending = data.pendingPayments + data.pendingLoans + data.pendingHeads;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Dashboard</h1>
        <div style={{ display: "flex", gap: 8 }}>
          <button className="btn btn-outline btn-sm" onClick={exportDashboard}>Export CSV</button>
        </div>
      </div>

      {actionMsg && (
        <div className="admin-banner success" role="status" data-testid="dashboard-action-msg">
          {actionMsg}
        </div>
      )}

      <div className="stat-grid">
        <div className="stat-card gradient">
          <div className="stat-label">Total Fund</div>
          <div className="stat-value">₱{fmt(data.totalContributions + data.totalInterest)}</div>
          <div className="stat-sub">₱{fmt(data.fundBalance)} available balance</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Active Members</div>
          <div className="stat-value">{data.activeMembers}</div>
          <div className="stat-sub">{data.totalHeads} total heads · of {data.totalMembers} registered</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Loans</div>
          <div className="stat-value">{data.activeLoans} active</div>
          <div className="stat-sub">{data.overdueLoans} overdue · {data.totalLoansIssued > 0 ? `₱${fmt(data.totalLoansIssued)} issued` : "No loans yet"}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Interest Earned</div>
          <div className="stat-value">₱{fmt(data.totalInterest)}</div>
          <div className="stat-sub">₱{fmt(data.perHeadShare)} per head share</div>
        </div>
      </div>

      <div className="fund-health-grid">
        <div className="fund-health-card">
          <div className="fund-health-header">
            <span className="fund-health-title">Fund Utilization</span>
            <span className={`fund-health-pct ${data.fundUtilization > 70 ? "warning" : data.fundUtilization > 40 ? "accent" : "success"}`}>
              {data.fundUtilization.toFixed(1)}%
            </span>
          </div>
          <div className="fund-health-bar-track">
            <div
              className={`fund-health-bar-fill ${data.fundUtilization > 70 ? "warning" : data.fundUtilization > 40 ? "accent" : "success"}`}
              style={{ width: `${Math.min(data.fundUtilization, 100)}%` }}
            />
          </div>
          <div className="fund-health-sub">
            {data.fundUtilization > 70 ? "High utilization — monitor repayments" :
             data.fundUtilization > 40 ? "Healthy lending activity" :
             "Low utilization — consider issuing more loans"}
          </div>
        </div>
        <div className="fund-health-card">
          <div className="fund-health-header">
            <span className="fund-health-title">Collection Rate (This Month)</span>
            <span className={`fund-health-pct ${data.collectionRate < 50 ? "error" : data.collectionRate < 80 ? "warning" : "success"}`}>
              {data.collectionRate.toFixed(1)}%
            </span>
          </div>
          <div className="fund-health-bar-track">
            <div
              className={`fund-health-bar-fill ${data.collectionRate < 50 ? "error" : data.collectionRate < 80 ? "warning" : "success"}`}
              style={{ width: `${Math.min(data.collectionRate, 100)}%` }}
            />
          </div>
          <div className="fund-health-sub">
            ₱{fmt(data.monthlyContributionsCurrent)} collected of ₱{fmt(data.monthlyRequiredCurrent)} required
          </div>
        </div>
        <div className="fund-health-card">
          <div className="fund-health-header">
            <span className="fund-health-title">Per-Head Share</span>
            <span className="fund-health-pct accent">₱{fmt(data.perHeadShare)}</span>
          </div>
          <div className="fund-health-sub" style={{ marginTop: 12 }}>
            Total interest pool divided across {data.totalHeads} heads
          </div>
        </div>
      </div>

      <div className="mini-stats">
        <div className="mini-stat">
          <span className="mini-stat-label">Total Loans Issued</span>
          <span className="mini-stat-value">₱{fmt(data.totalLoansIssued)}</span>
        </div>
        <div className="mini-stat warning">
          <span className="mini-stat-label">Overdue</span>
          <span className="mini-stat-value">{data.overdueLoans}</span>
        </div>
        <div className="mini-stat accent">
          <span className="mini-stat-label">Avg Contribution</span>
          <span className="mini-stat-value">₱{fmt(data.avgContributionPerMember)}</span>
        </div>
        <div className="mini-stat" style={{ borderColor: totalPending > 0 ? "#f59e0b" : undefined }}>
          <span className="mini-stat-label">Pending Approvals</span>
          <span className="mini-stat-value" style={{ color: totalPending > 0 ? "#f59e0b" : "#22c55e" }}>{totalPending}</span>
        </div>
      </div>

      <div className="annual-returns">
        <div className="annual-returns-title">{new Date().getFullYear()} Annual Returns</div>
        <div className="annual-returns-grid">
          <div className="annual-return-item">
            <span className="annual-return-label">Contributions</span>
            <span className="annual-return-value" style={{ color: "#22c55e" }}>₱{fmt(data.annualContributions)}</span>
          </div>
          <div className="annual-return-item">
            <span className="annual-return-label">Loans Issued</span>
            <span className="annual-return-value" style={{ color: "#f59e0b" }}>₱{fmt(data.annualLoans)}</span>
          </div>
          <div className="annual-return-item">
            <span className="annual-return-label">Repayments</span>
            <span className="annual-return-value" style={{ color: "#3b82f6" }}>₱{fmt(data.annualRepayments)}</span>
          </div>
          <div className="annual-return-item highlight-item">
            <span className="annual-return-label">Net Returns</span>
            <span className="annual-return-value" style={{ color: data.annualReturns >= 0 ? "#22c55e" : "#ef4444" }}>₱{fmt(data.annualReturns)}</span>
          </div>
        </div>
      </div>

      <div className="dashboard-actions">
        <button className="btn btn-primary" onClick={() => setActionModal("contribution")}>+ New Contribution</button>
        <button className="btn btn-outline" style={{ borderColor: "#f59e0b", color: "#f59e0b" }} onClick={() => setActionModal("loan")}>+ Issue Loan</button>
        <button className="btn btn-outline" style={{ borderColor: "#3b82f6", color: "#3b82f6" }} onClick={() => setActionModal("repayment")}>+ Record Repayment</button>
        <button className="btn btn-outline" style={{ borderColor: "#f59e0b", color: "#f59e0b", fontWeight: "bold" }} onClick={handleBackfill}>Backfill Member IDs</button>
        <button className="btn btn-outline" onClick={() => window.location.href="/admin/approvals"}>
          Pending ({totalPending})
        </button>
      </div>

      <div className="charts-section">
        <div className="tabs" style={{ marginBottom: 16 }}>
          {["Monthly Trends", "Status", "Top Members"].map((t,i) => (
            <button key={t} className={`tab ${i===chartTab?"active":""}`} onClick={()=>setChartTab(i)}>{t}</button>
          ))}
        </div>

        {chartTab === 0 && (
          <div className="chart-card">
            <h3>Monthly Contributions & Loans (6 months)</h3>
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={data.monthlyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#21262d" />
                <XAxis dataKey="month" stroke="#8b949e" fontSize={11} />
                <YAxis stroke="#8b949e" fontSize={11} />
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend />
                <Bar dataKey="contributions" name="Contributions" fill="#22c55e" radius={[4,4,0,0]} />
                <Bar dataKey="loans" name="Loans Issued" fill="#f59e0b" radius={[4,4,0,0]} />
                <Bar dataKey="repayments" name="Repayments" fill="#3b82f6" radius={[4,4,0,0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}

        {chartTab === 1 && (
          <div className="chart-card">
            <h3>Transaction Status Distribution</h3>
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie data={data.loanStatusData.filter(d=>d.value>0)} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={100} label={({name,value}) => `${name}: ${value}`}>
                  {data.loanStatusData.filter(d=>d.value>0).map((_,i) => <Cell key={i} fill={COLORS[i%COLORS.length]} />)}
                </Pie>
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8 }} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}

        {chartTab === 2 && (
          <div className="chart-card">
            <h3>Top Members by Contributions</h3>
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={data.topMembers} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="#21262d" />
                <XAxis type="number" stroke="#8b949e" fontSize={11} />
                <YAxis dataKey="name" type="category" stroke="#8b949e" fontSize={11} width={100} />
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend />
                <Bar dataKey="contributions" name="Contributions" fill="#22c55e" radius={[0,4,4,0]} />
                <Bar dataKey="loans" name="Loans" fill="#f59e0b" radius={[0,4,4,0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      <div className="section"><h2>Recent Activity</h2>
        {data.recentActivity.length === 0 ? <p className="empty-text">No recent activity</p> : (
          <div className="activity-list">{data.recentActivity.map((item,i) => (
            <div key={i} className="activity-item">
              <div className={`activity-dot ${item.status==="approved"?"success":item.status==="rejected"?"error":"pending"}`} />
              <div className="activity-info"><div className="activity-title">{item.type}</div><div className="activity-sub">{item.description}</div></div>
              <div className={`activity-amount ${item.status==="approved"?"text-success":item.status==="rejected"?"text-error":"text-pending"}`}>{item.amount}</div>
            </div>
          ))}</div>
        )}
      </div>

      {actionModal && <QuickActionModal type={actionModal} members={data.memberNames} onSave={handleQuickAction} onClose={() => setActionModal(null)} />}
    </div>
  );
};

const QuickActionModal: React.FC<{
  type: string;
  members: Record<string, string>;
  onSave: (type: string, data: Record<string, unknown>) => Promise<void>;
  onClose: () => void;
}> = ({ type, members, onSave, onClose }) => {
  const [memberId, setMemberId] = useState("");
  const [amount, setAmount] = useState("");
  const [notes, setNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const titles: Record<string, string> = {
    contribution: "New Contribution",
    loan: "Issue Loan",
    repayment: "Record Repayment",
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!memberId || !amount) return;
    const amt = Number(amount);
    if (!Number.isFinite(amt) || amt <= 0) {
      alert("Amount must be greater than 0.");
      return;
    }
    setSubmitting(true);
    try {
      const data: Record<string, unknown> = { memberId, amount: amt };
      const trimmed = notes.trim();
      if (trimmed) data.notes = trimmed;
      if (type === "loan") {
        data.principal = amt;
        data.dueDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
        data.interestRate = 0.1;
      }
      await onSave(type, data);
    } finally { setSubmitting(false); }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>{titles[type]}</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Member</label>
            <select value={memberId} onChange={e => setMemberId(e.target.value)} required>
              <option value="">Select member...</option>
              {Object.entries(members).map(([id, name]) => <option key={id} value={id}>{name}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label>Amount (₱)</label>
            <input type="number" min="0" step="0.01" value={amount} onChange={e => setAmount(e.target.value)} required />
          </div>
          <div className="form-group">
            <label>Notes (optional)</label>
            <input type="text" value={notes} onChange={e => setNotes(e.target.value)} />
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-outline" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? "Saving..." : "Submit"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default Dashboard;
