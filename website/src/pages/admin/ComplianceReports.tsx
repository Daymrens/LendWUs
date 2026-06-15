import React, { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../../firebase";

interface ComplianceData {
  totalMembers: number;
  activeMembers: number;
  totalLoans: number;
  activeLoans: number;
  totalContributions: number;
  totalLoansIssued: number;
  totalRepaid: number;
  outstandingBalance: number;
  fundBalance: number;
}

const ComplianceReports: React.FC = () => {
  const [data, setData] = useState<ComplianceData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    setError("");
    try {
      const [mSnap, lSnap, cSnap, rSnap] = await Promise.all([
        getDocs(collection(db, "members")),
        getDocs(collection(db, "loans")),
        getDocs(collection(db, "contributions")),
        getDocs(collection(db, "repayments")),
      ]);

      const members = mSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      const activeMembers = members.filter((m: any) => m.isActive !== false);

      const loans = lSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      const activeLoans = loans.filter((l: any) => !l.isFullyRepaid);

      const totalContributions = cSnap.docs.reduce((s, d) => s + (Number(d.data().amount) || 0), 0);
      const totalLoansIssued = lSnap.docs.reduce((s, d) => s + (Number(d.data().principal) || 0), 0);
      const totalRepaid = rSnap.docs.reduce((s, d) => s + (Number(d.data().amountPaid) || 0), 0);

      let outstandingBalance = 0;
      for (const loan of activeLoans) {
        const loanRepayments = rSnap.docs.filter(d => d.data().loanId === (loan as any).id);
        const repaid = loanRepayments.reduce((s, d) => s + (Number(d.data().amountPaid) || 0), 0);
        const rate = Number((loan as any).interestRate) || 0;
        const principal = Number((loan as any).principal) || 0;
        const totalDue = principal + principal * rate;
        outstandingBalance += Math.max(0, totalDue - repaid);
      }

      const fundBalance = totalContributions - totalLoansIssued + totalRepaid;

      setData({
        totalMembers: members.length,
        activeMembers: activeMembers.length,
        totalLoans: loans.length,
        activeLoans: activeLoans.length,
        totalContributions,
        totalLoansIssued,
        totalRepaid,
        outstandingBalance,
        fundBalance,
      });
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load data");
    } finally {
      setLoading(false);
    }
  };

  const section = (title: string, cards: { label: string; value: string; color: string }[]) => (
    <div style={{ marginBottom: 24 }}>
      <h3 style={{ marginBottom: 8 }}>{title}</h3>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 8 }}>
        {cards.map(c => (
          <div key={c.label} className="card" style={{ padding: 16 }}>
            <div style={{ fontSize: 13, color: "#8b949e" }}>{c.label}</div>
            <div style={{ fontWeight: 700, fontSize: 18, color: c.color }}>{c.value}</div>
          </div>
        ))}
      </div>
    </div>
  );

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading compliance data...</p></div>;
  if (error) return <div className="admin-error"><p>{error}</p></div>;
  if (!data) return null;

  return (
    <div className="page-container">
      <div className="page-header">
        <h1>Compliance Reports</h1>
        <button className="btn btn-outline btn-sm" onClick={loadData}>Refresh</button>
      </div>
      {section("Membership", [
        { label: "Total Members", value: String(data.totalMembers), color: "#22c55e" },
        { label: "Active Members", value: String(data.activeMembers), color: "#3b82f6" },
      ])}
      {section("Loans", [
        { label: "Total Loans", value: String(data.totalLoans), color: "#f97316" },
        { label: "Active Loans", value: String(data.activeLoans), color: "#ef4444" },
      ])}
      {section("Financial Summary", [
        { label: "Total Contributions", value: `₱${data.totalContributions.toLocaleString()}`, color: "#22c55e" },
        { label: "Total Loans Issued", value: `₱${data.totalLoansIssued.toLocaleString()}`, color: "#ef4444" },
        { label: "Total Repaid", value: `₱${data.totalRepaid.toLocaleString()}`, color: "#3b82f6" },
        { label: "Outstanding Balance", value: `₱${data.outstandingBalance.toLocaleString()}`, color: "#f97316" },
        { label: "Fund Balance", value: `₱${data.fundBalance.toLocaleString()}`, color: "#22c55e" },
      ])}
    </div>
  );
};

export default ComplianceReports;
