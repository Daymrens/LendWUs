import React, { useEffect, useState } from "react";
import { collection, getDocs, Timestamp } from "firebase/firestore";
import { db } from "../../firebase";
import { downloadCSV } from "../../utils/export";

const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

const Reports: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [monthlyReports, setMonthlyReports] = useState<Array<{
    month: string; contributions: number; contributionCount: number;
    loansIssued: number; loanCount: number; repayments: number; repaymentCount: number;
    totalMembers: number; activeMembers: number;
  }>>([]);

  // eslint-disable-next-line react-hooks/exhaustive-deps
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
      const reportMap: Record<string, typeof monthlyReports[0]> = {};
      for (let i = 11; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const key = `${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
        reportMap[key] = { month: key, contributions:0, contributionCount:0, loansIssued:0, loanCount:0, repayments:0, repaymentCount:0, totalMembers: members.length, activeMembers: members.filter((m: Record<string,unknown>) => m.isActive===true||m.isActive===1).length };
      }

      contributions.forEach((c: Record<string,unknown>) => {
        const cd = (c.date as Timestamp)?.toDate?.() || new Date(String(c.date));
        const key = `${MONTHS[cd.getMonth()]} ${cd.getFullYear()}`;
        if (reportMap[key]) { reportMap[key].contributions += Number(c.amount)||0; reportMap[key].contributionCount++; }
      });
      loans.forEach((l: Record<string,unknown>) => {
        const ld = (l.issuedDate as Timestamp)?.toDate?.() || new Date(String(l.issuedDate));
        const key = `${MONTHS[ld.getMonth()]} ${ld.getFullYear()}`;
        if (reportMap[key]) { reportMap[key].loansIssued += Number(l.principal)||0; reportMap[key].loanCount++; }
      });
      payments.filter((p: Record<string,unknown>) => p.type==="loan" && p.status==="approved").forEach((p: Record<string,unknown>) => {
        const pd = (p.approvedDate as Timestamp)?.toDate?.() || new Date(String(p.date));
        const key = `${MONTHS[pd.getMonth()]} ${pd.getFullYear()}`;
        if (reportMap[key]) { reportMap[key].repayments += Number(p.amount)||0; reportMap[key].repaymentCount++; }
      });

      setMonthlyReports(Object.values(reportMap));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  const exportReport = () => {
    downloadCSV(monthlyReports, "monthly_reports");
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading reports...</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Monthly Reports</h1>
        <button className="btn btn-outline btn-sm" onClick={exportReport}>Export CSV</button>
      </div>

      <div className="table-wrap">
        <table className="data-table">
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
            {monthlyReports.map(r => (
              <tr key={r.month}>
                <td><strong>{r.month}</strong></td>
                <td className="text-success">₱{r.contributions.toLocaleString()}</td>
                <td>{r.contributionCount}</td>
                <td className="text-pending">₱{r.loansIssued.toLocaleString()}</td>
                <td>{r.loanCount}</td>
                <td className="text-success">₱{r.repayments.toLocaleString()}</td>
                <td>{r.repaymentCount}</td>
                <td>{r.activeMembers}/{r.totalMembers}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Reports;
