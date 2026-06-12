import React, { useEffect, useState, useMemo } from "react";
import { collection, getDocs, Timestamp } from "firebase/firestore";
import { db } from "../../firebase";
import { downloadCSV } from "../../utils/export";

const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

interface MonthlyRow {
  month: string;
  contributions: number;
  contributionCount: number;
  loansIssued: number;
  loanCount: number;
  repayments: number;
  repaymentCount: number;
  totalMembers: number;
  activeMembers: number;
}

const Reports: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [allReports, setAllReports] = useState<MonthlyRow[]>([]);
  const [yearFilter, setYearFilter] = useState("all");

  useEffect(() => { loadReports(); }, []);

  const loadReports = async () => {
    setLoading(true);
    try {
      const [membersSnap, contribSnap, loansSnap, paySnap] = await Promise.all([
        getDocs(collection(db, "members")),
        getDocs(collection(db, "contributions")),
        getDocs(collection(db, "loans")),
        getDocs(collection(db, "payment_requests")),
      ]);
      const members = membersSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      const contributions = contribSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      const loans = loansSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      const payments = paySnap.docs.map(d => ({ id: d.id, ...d.data() }));

      const now = new Date();
      const reportMap: Record<string, MonthlyRow> = {};
      for (let i = 11; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const key = `${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
        reportMap[key] = {
          month: key, contributions: 0, contributionCount: 0,
          loansIssued: 0, loanCount: 0, repayments: 0, repaymentCount: 0,
          totalMembers: members.length,
          activeMembers: members.filter((m: Record<string,unknown>) => m.isActive === true || m.isActive === 1).length,
        };
      }

      contributions.forEach((c: Record<string,unknown>) => {
        const cd = (c.date as Timestamp)?.toDate?.() || new Date(String(c.date));
        const key = `${MONTHS[cd.getMonth()]} ${cd.getFullYear()}`;
        if (reportMap[key]) {
          reportMap[key].contributions += Number(c.amount) || 0;
          reportMap[key].contributionCount++;
        }
      });

      loans.forEach((l: Record<string,unknown>) => {
        const ld = (l.issuedDate as Timestamp)?.toDate?.() || new Date(String(l.issuedDate));
        const key = `${MONTHS[ld.getMonth()]} ${ld.getFullYear()}`;
        if (reportMap[key]) {
          reportMap[key].loansIssued += Number(l.principal) || 0;
          reportMap[key].loanCount++;
        }
      });

      payments
        .filter((p: Record<string,unknown>) => p.type === "loan" && p.status === "approved")
        .forEach((p: Record<string,unknown>) => {
          const pd = (p.approvedDate as Timestamp)?.toDate?.() || new Date(String(p.date));
          const key = `${MONTHS[pd.getMonth()]} ${pd.getFullYear()}`;
          if (reportMap[key]) {
            reportMap[key].repayments += Number(p.amount) || 0;
            reportMap[key].repaymentCount++;
          }
        });

      setAllReports(Object.values(reportMap));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  const years = useMemo(() => {
    const s = new Set<string>();
    allReports.forEach(r => s.add(r.month.split(" ")[1]));
    const result: string[] = [];
    s.forEach(y => result.push(y));
    return result.sort();
  }, [allReports]);

  const reports = useMemo(() => {
    if (yearFilter === "all") return allReports;
    return allReports.filter(r => r.month.includes(yearFilter));
  }, [allReports, yearFilter]);

  const summary = useMemo(() => {
    return {
      contributions: reports.reduce((s, r) => s + r.contributions, 0),
      loansIssued: reports.reduce((s, r) => s + r.loansIssued, 0),
      repayments: reports.reduce((s, r) => s + r.repayments, 0),
      avgContrib: reports.length ? reports.reduce((s, r) => s + r.contributions, 0) / reports.length : 0,
      avgLoans: reports.length ? reports.reduce((s, r) => s + r.loansIssued, 0) / reports.length : 0,
    };
  }, [reports]);

  const maxContrib = Math.max(...reports.map(r => r.contributions), 1);

  const exportReport = () => {
    downloadCSV(reports as unknown as Record<string, unknown>[], "monthly_reports");
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading reports...</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Monthly Reports</h1>
        <button className="btn btn-outline btn-sm" onClick={exportReport}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          Export CSV
        </button>
      </div>

      <div className="reports-summary">
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(34,197,94,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">Total Contributions</span>
            <span className="report-summary-value text-success">₱{summary.contributions.toLocaleString()}</span>
            <span className="report-summary-sub">Avg ₱{Math.round(summary.avgContrib).toLocaleString()}/mo</span>
          </div>
        </div>
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(245,158,11,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">Total Loans Issued</span>
            <span className="report-summary-value text-pending">₱{summary.loansIssued.toLocaleString()}</span>
            <span className="report-summary-sub">{reports.reduce((s, r) => s + r.loanCount, 0)} loans processed</span>
          </div>
        </div>
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(59,130,246,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#3b82f6" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">Total Repayments</span>
            <span className="report-summary-value" style={{ color: "#3b82f6" }}>₱{summary.repayments.toLocaleString()}</span>
            <span className="report-summary-sub">{reports.reduce((s, r) => s + r.repaymentCount, 0)} repayments</span>
          </div>
        </div>
        <div className="report-summary-card">
          <div className="report-summary-icon" style={{ background: "rgba(139,148,158,0.12)" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#8b949e" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>
          </div>
          <div className="report-summary-body">
            <span className="report-summary-label">Net Returns</span>
            <span className={`report-summary-value ${summary.contributions - summary.loansIssued >= 0 ? "text-success" : "text-error"}`}>
              ₱{(summary.contributions - summary.loansIssued).toLocaleString()}
            </span>
            <span className="report-summary-sub">Contributions - Loans</span>
          </div>
        </div>
      </div>

      <div className="reports-controls">
        <select className="search-input" value={yearFilter} onChange={e => setYearFilter(e.target.value)} style={{ width: "auto", marginBottom: 0 }}>
          <option value="all">All Years</option>
          {years.map(y => <option key={y} value={y}>{y}</option>)}
        </select>
        <span className="reports-count">{reports.length} months</span>
      </div>

      <div className="reports-chart">
        <div className="reports-chart-header">
          <span>Monthly Contributions vs Loans</span>
        </div>
        <div className="reports-bars">
          {reports.map(r => {
            const contribPct = (r.contributions / maxContrib) * 100;
            const loanPct = (r.loansIssued / maxContrib) * 100;
            return (
              <div key={r.month} className="reports-bar-col">
                <div className="reports-bar-group">
                  <div className="reports-bar-track">
                    <div className="reports-bar reports-bar-contrib" style={{ height: `${Math.max(contribPct, 2)}%` }} title={`Contributions: ₱${r.contributions.toLocaleString()}`} />
                  </div>
                  <div className="reports-bar-track">
                    <div className="reports-bar reports-bar-loan" style={{ height: `${Math.max(loanPct, 2)}%` }} title={`Loans: ₱${r.loansIssued.toLocaleString()}`} />
                  </div>
                </div>
                <div className="reports-bar-label">{r.month.split(" ")[0]}</div>
              </div>
            );
          })}
        </div>
        <div className="reports-chart-legend">
          <span><span className="legend-dot" style={{ background: "#22c55e" }} /> Contributions</span>
          <span><span className="legend-dot" style={{ background: "#f59e0b" }} /> Loans Issued</span>
        </div>
      </div>

      <div className="table-wrap">
        <table className="data-table reports-table">
          <thead>
            <tr>
              <th>Month</th>
              <th>Contributions</th>
              <th>#</th>
              <th>Loans Issued</th>
              <th>#</th>
              <th>Repayments</th>
              <th>#</th>
              <th>Active Members</th>
            </tr>
          </thead>
          <tbody>
            {reports.map(r => {
              const barW = (r.contributions / maxContrib) * 100;
              return (
                <tr key={r.month}>
                  <td><strong>{r.month}</strong></td>
                  <td>
                    <div className="reports-table-bar-wrap">
                      <div className="reports-table-bar" style={{ width: `${barW}%` }} />
                      <span className="reports-table-bar-label">₱{r.contributions.toLocaleString()}</span>
                    </div>
                  </td>
                  <td className="reports-count-cell">{r.contributionCount}</td>
                  <td className="text-pending">₱{r.loansIssued.toLocaleString()}</td>
                  <td className="reports-count-cell">{r.loanCount}</td>
                  <td style={{ color: "#3b82f6" }}>₱{r.repayments.toLocaleString()}</td>
                  <td className="reports-count-cell">{r.repaymentCount}</td>
                  <td>{r.activeMembers}/{r.totalMembers}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Reports;
