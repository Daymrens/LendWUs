import React, { useEffect, useMemo, useState, useRef } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  limit,
  addDoc,
  getDoc,
  getDocs,
  updateDoc,
  doc,
  onSnapshot,
  Timestamp,
} from "firebase/firestore";
import { db } from "../../firebase";
import { downloadCSV } from "../../utils/export";
import { backfillMissingMemberIds } from "../../utils/memberId";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend, Area, AreaChart,
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
  fundGrowthData: Array<{ day: number; currentBalance: number; previousBalance: number | null }>;
  prevMonthLabel: string;
  paymentStatusData: Array<{ name: string; value: number; color: string }>;
  collectionRateTrend: Array<{ month: string; rate: number }>;
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
  const now = new Date();
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
    const activeMembers = members.filter((m) => m.active === true || m.active === 1 || m.isActive === true || m.isActive === 1).length;
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

    const activeMembersList = members.filter((m) => m.active === true || m.active === 1 || m.isActive === true || m.isActive === 1);
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
    const monthlyRequiredCurrent = activeMembersList.reduce((s, m) => s + (Number(m.headsCount) || 1) * (Number(m.amountPerHead) || 500), 0);
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

    const daysInMonth = new Date(thisYear, thisMonth, 0).getDate();
    const fundGrowthData: Array<{ day: number; currentBalance: number; previousBalance: number | null }> = [];
    const balanceBeforeMonth = contributions
      .filter((c) => {
        const d = (c.date as Timestamp)?.toDate?.();
        return d && (d.getFullYear() < thisYear || (d.getFullYear() === thisYear && d.getMonth() + 1 < thisMonth));
      })
      .reduce((s, c) => s + (Number(c.amount)||0), 0)
      - loans
        .filter((l) => {
          const d = (l.issuedDate as Timestamp)?.toDate?.();
          return d && (d.getFullYear() < thisYear || (d.getFullYear() === thisYear && d.getMonth() + 1 < thisMonth));
        })
        .reduce((s, l) => s + (Number(l.principal)||0), 0)
      + repaymentsData
        .filter((r) => {
          const d = (r.date as Timestamp)?.toDate?.();
          return d && (d.getFullYear() < thisYear || (d.getFullYear() === thisYear && d.getMonth() + 1 < thisMonth));
        })
        .reduce((s, r) => s + (Number(r.amountPaid)||0), 0);
    let running = balanceBeforeMonth;
    for (let day = 1; day <= daysInMonth; day++) {
      contributions
        .filter((c) => {
          const d = (c.date as Timestamp)?.toDate?.();
          if (!d) return false;
          return d.getFullYear() === thisYear && d.getMonth() + 1 === thisMonth && d.getDate() === day;
        })
        .forEach((c) => { running += Number(c.amount)||0; });
      loans
        .filter((l) => {
          const d = (l.issuedDate as Timestamp)?.toDate?.();
          if (!d) return false;
          return d.getFullYear() === thisYear && d.getMonth() + 1 === thisMonth && d.getDate() === day;
        })
        .forEach((l) => { running -= Number(l.principal)||0; });
      repaymentsData
        .filter((r) => {
          const d = (r.date as Timestamp)?.toDate?.();
          if (!d) return false;
          return d.getFullYear() === thisYear && d.getMonth() + 1 === thisMonth && d.getDate() === day;
        })
        .forEach((r) => { running += Number(r.amountPaid)||0; });
      fundGrowthData.push({ day, currentBalance: running, previousBalance: null });
    }

    const prevMonth = thisMonth === 1 ? 12 : thisMonth - 1;
    const prevYear = thisMonth === 1 ? thisYear - 1 : thisYear;
    const prevDaysInMonth = new Date(prevYear, prevMonth, 0).getDate();
    const prevBalanceBefore = contributions
      .filter((c) => {
        const d = (c.date as Timestamp)?.toDate?.();
        return d && (d.getFullYear() < prevYear || (d.getFullYear() === prevYear && d.getMonth() + 1 < prevMonth));
      })
      .reduce((s, c) => s + (Number(c.amount)||0), 0)
      - loans
        .filter((l) => {
          const d = (l.issuedDate as Timestamp)?.toDate?.();
          return d && (d.getFullYear() < prevYear || (d.getFullYear() === prevYear && d.getMonth() + 1 < prevMonth));
        })
        .reduce((s, l) => s + (Number(l.principal)||0), 0)
      + repaymentsData
        .filter((r) => {
          const d = (r.date as Timestamp)?.toDate?.();
          return d && (d.getFullYear() < prevYear || (d.getFullYear() === prevYear && d.getMonth() + 1 < prevMonth));
        })
        .reduce((s, r) => s + (Number(r.amountPaid)||0), 0);
    let prevRunning = prevBalanceBefore;
    for (let day = 1; day <= daysInMonth; day++) {
      if (day <= prevDaysInMonth) {
        contributions
          .filter((c) => {
            const d = (c.date as Timestamp)?.toDate?.();
            if (!d) return false;
            return d.getFullYear() === prevYear && d.getMonth() + 1 === prevMonth && d.getDate() === day;
          })
          .forEach((c) => { prevRunning += Number(c.amount)||0; });
        loans
          .filter((l) => {
            const d = (l.issuedDate as Timestamp)?.toDate?.();
            if (!d) return false;
            return d.getFullYear() === prevYear && d.getMonth() + 1 === prevMonth && d.getDate() === day;
          })
          .forEach((l) => { prevRunning -= Number(l.principal)||0; });
        repaymentsData
          .filter((r) => {
            const d = (r.date as Timestamp)?.toDate?.();
            if (!d) return false;
            return d.getFullYear() === prevYear && d.getMonth() + 1 === prevMonth && d.getDate() === day;
          })
          .forEach((r) => { prevRunning += Number(r.amountPaid)||0; });
      }
      if (day <= fundGrowthData.length) {
        fundGrowthData[day - 1].previousBalance = day <= prevDaysInMonth ? prevRunning : prevRunning;
      }
    }
    const prevMonthLabel = `${MONTHS[prevMonth - 1]} ${prevYear}`;

    const paidCount = activeMembersList.filter((m) => {
      const mid = m.id;
      const memberContribsThisMonth = contributions
        .filter((c) => {
          const d = (c.date as Timestamp)?.toDate?.();
          return d && d.getMonth() + 1 === thisMonth && d.getFullYear() === thisYear && c.memberId === mid;
        })
        .reduce((s, c) => s + (Number(c.amount)||0), 0);
      const required = (Number(m.headsCount) || 1) * (Number(m.amountPerHead) || 500);
      return required > 0 && memberContribsThisMonth >= required;
    }).length;
    const pendingCount = activeMembersList.filter((m) => {
      const mid = m.id;
      return contributions
        .filter((c) => {
          const d = (c.date as Timestamp)?.toDate?.();
          return d && d.getMonth() + 1 === thisMonth && d.getFullYear() === thisYear && c.memberId === mid;
        })
        .reduce((s, c) => s + (Number(c.amount)||0), 0) === 0;
    }).length;
    const partialCount = activeMembersList.length - paidCount - pendingCount;
    const paymentStatusData = [
      { name: "Paid", value: paidCount, color: "#22c55e" },
      { name: "Pending", value: pendingCount, color: "#f59e0b" },
      { name: "Partial", value: partialCount, color: "#3b82f6" },
    ].filter(d => d.value > 0);

    const collectionRateTrend: Array<{ month: string; rate: number }> = [];
    const activeMembersTotalRequired = activeMembersList.reduce((s, m) => s + (Number(m.headsCount) || 1) * (Number(m.amountPerHead) || 500), 0);
    for (let i = 5; i >= 0; i--) {
      const d = new Date(); d.setMonth(d.getMonth() - i);
      const m = d.getMonth() + 1;
      const y = d.getFullYear();
      const monthTotal = contributions
        .filter((c) => {
          const cd = (c.date as Timestamp)?.toDate?.();
          return cd && cd.getMonth() + 1 === m && cd.getFullYear() === y;
        })
        .reduce((s, c) => s + (Number(c.amount)||0), 0);
      const trendLabel = `${MONTHS[d.getMonth()]} ${y}`;
      collectionRateTrend.push({
        month: trendLabel,
        rate: activeMembersTotalRequired > 0 ? (monthTotal / activeMembersTotalRequired) * 100 : 0,
      });
    }

    return { totalMembers, activeMembers, totalContributions, totalLoansIssued, activeLoans, overdueLoans, fundBalance, totalInterest, pendingPayments, pendingLoans, pendingHeads, recentActivity, monthlyData, loanStatusData, topMembers, memberNames, annualReturns, annualContributions, annualLoans, annualRepayments, totalHeads, perHeadShare, fundUtilization, collectionRate, monthlyContributionsCurrent, monthlyRequiredCurrent, avgContributionPerMember, fundGrowthData, prevMonthLabel, paymentStatusData, collectionRateTrend };
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
        await addDoc(collection(db, "contributions"), {
          memberId: formData.memberId,
          amount: formData.amount,
          date: now,
          month: d.getMonth() + 1,
          year: d.getFullYear(),
          notes: (formData.notes as string) || null,
          createdBy: "admin",
        });
      } else if (type === "loan") {
        const principal = formData.amount as number;
        if (principal <= 0) { alert("Loan amount must be greater than zero"); return; }

        const memberSnap = await getDoc(doc(db, "members", formData.memberId as string));
        if (!memberSnap.exists() || memberSnap.data()?.isActive !== true) {
          alert("Member is not active"); return;
        }

        const dueDate = formData.dueDate as Date;
        if (dueDate <= new Date()) { alert("Due date must be in the future"); return; }

        const [contribSnap, loanSnap, repaySnap] = await Promise.all([
          getDocs(collection(db, "contributions")),
          getDocs(collection(db, "loans")),
          getDocs(collection(db, "repayments")),
        ]);
        const totalContributions = contribSnap.docs.reduce((s, d) => s + (Number(d.data().amount) || 0), 0);
        const totalLoansIssued = loanSnap.docs.reduce((s, d) => s + (Number(d.data().principal) || 0), 0);
        const totalRepayments = repaySnap.docs.reduce((s, d) => s + (Number(d.data().amountPaid) || 0), 0);
        const fundBalance = totalContributions - totalLoansIssued + totalRepayments;

        const outstandingBalances = loanSnap.docs
          .filter(d => d.data().isFullyRepaid !== true)
          .reduce((s, d) => {
            const ln = d.data();
            const p = Number(ln.principal) || 0;
            const r = Number(ln.interestRate) || 0;
            const totalDue = p + (p * r);
            const repaid = repaySnap.docs
              .filter(rp => rp.data().loanId === d.id)
              .reduce((s2, rp) => s2 + (Number(rp.data().amountPaid) || 0), 0);
            return s + Math.max(0, totalDue - repaid);
          }, 0);
        const availableToLoan = fundBalance - outstandingBalances;
        if (principal > availableToLoan) {
          alert(`Insufficient fund balance. Available: ₱${availableToLoan.toLocaleString()}`);
          return;
        }

        const activeLoansForMember = loanSnap.docs.filter(
          l => l.data().memberId === formData.memberId && l.data().isFullyRepaid !== true
        );
        if (activeLoansForMember.length > 0) {
          alert("Member already has an unpaid loan"); return;
        }

        const interestRate = (Number(formData.interestRate) || 10) / 100;
        await addDoc(collection(db, "loans"), {
          memberId: formData.memberId,
          principal: principal,
          interestRate: interestRate,
          issuedDate: now,
          dueDate: Timestamp.fromDate(dueDate),
          isFullyRepaid: false,
        });
      } else if (type === "repayment") {
        const loanId = formData.loanId as string;
        const amountPaid = formData.amount as number;
        if (amountPaid <= 0) { alert("Repayment amount must be greater than zero"); return; }

        const loanSnap = await getDoc(doc(db, "loans", loanId));
        if (!loanSnap.exists()) { alert("Loan not found"); return; }
        const loan = loanSnap.data();
        const p = Number(loan.principal) || 0;
        const r = Number(loan.interestRate) || 0;
        const totalDue = p + (p * r);

        const repayQ = query(collection(db, "repayments"), where("loanId", "==", loanId));
        const repaySnap = await getDocs(repayQ);
        const totalRepaid = repaySnap.docs.reduce((s, rp) => s + (Number(rp.data().amountPaid) || 0), 0);
        const remainingBalance = Math.max(0, totalDue - totalRepaid);

        if (amountPaid > remainingBalance) {
          if (!window.confirm(`Amount exceeds remaining balance (₱${remainingBalance.toLocaleString()}). Excess will be credited to member. Proceed?`)) return;
        }

        await addDoc(collection(db, "repayments"), {
          loanId: loanId,
          amountPaid: amountPaid,
          date: now,
        });

        if (amountPaid >= remainingBalance) {
          await updateDoc(doc(db, "loans", loanId), { isFullyRepaid: true });
        }
      }

      setActionModal(null);
      const labels: Record<string, string> = { contribution: "Contribution", loan: "Loan", repayment: "Repayment" };
      setActionMsg(`${labels[type] || "Record"} saved successfully.`);
      setTimeout(() => setActionMsg(""), 3000);
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed");
    }
  };

  // New-pending-request notification modal (must be before early returns)
  const prevPendingRef = useRef(0);
  const initializedRef = useRef(false);
  const [showPendingModal, setShowPendingModal] = useState(false);
  const rawPendingCount = payments.filter(p => p.status === "pending").length
    + loanReqs.filter(r => r.status === "pending").length
    + heads.filter(h => h.status === "pending").length;
  useEffect(() => {
    if (!initializedRef.current) {
      prevPendingRef.current = rawPendingCount;
      initializedRef.current = true;
      return;
    }
    if (rawPendingCount > prevPendingRef.current) {
      setShowPendingModal(true);
    }
    prevPendingRef.current = rawPendingCount;
  }, [rawPendingCount]);

  if (firstLoad) return <div className="admin-loading"><div className="spinner" /><p>Loading dashboard...</p></div>;
  if (error) return <div className="admin-error"><p>Error: {error}</p><button className="btn btn-primary" onClick={refresh}>Retry</button></div>;
  if (!data) return null;

  const fmt = (n: number) => n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const totalPending = data.pendingPayments + data.pendingLoans + data.pendingHeads;

  const pendingPaymentsList = payments.filter(p => p.status === "pending");
  const pendingLoansList = loanReqs.filter(r => r.status === "pending");
  const pendingHeadsList = heads.filter(h => h.status === "pending");



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
          <div className="stat-sub">{data.totalHeads} total heads · {data.totalMembers} member{(data.totalMembers === 1) ? '' : 's'}</div>
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
          {["Monthly Trends", "Status", "Top Members", "Fund Growth", "Payments", "Collection Rate"].map((t,i) => (
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
                <YAxis stroke="#8b949e" fontSize={11} tickFormatter={(v: number) => `₱${(v/1000).toFixed(0)}k`} />
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend formatter={(value: string) => <span style={{ color:"#c9d1d9" }}>{value}</span>} />
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
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend formatter={(value: string) => <span style={{ color:"#c9d1d9" }}>{value}</span>} />
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
                <XAxis type="number" stroke="#8b949e" fontSize={11} tickFormatter={(v: number) => `₱${(v/1000).toFixed(0)}k`} />
                <YAxis dataKey="name" type="category" stroke="#8b949e" fontSize={11} width={100} />
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend formatter={(value: string) => <span style={{ color:"#c9d1d9" }}>{value}</span>} />
                <Bar dataKey="contributions" name="Contributions" fill="#22c55e" radius={[0,4,4,0]} />
                <Bar dataKey="loans" name="Loans" fill="#f59e0b" radius={[0,4,4,0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}

        {chartTab === 3 && (
          <div className="chart-card">
            <h3>Fund Balance Growth — {MONTHS[now.getMonth()]} {now.getFullYear()}</h3>
            <ResponsiveContainer width="100%" height={280}>
              <AreaChart data={data.fundGrowthData}>
                <defs>
                  <linearGradient id="fundGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="prevGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.2} />
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#21262d" />
                <XAxis dataKey="day" stroke="#8b949e" fontSize={11} tickCount={7} />
                <YAxis stroke="#8b949e" fontSize={11} tickFormatter={(v: number) => `₱${(v/1000).toFixed(0)}k`} />
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend formatter={(value: string) => <span style={{ color:"#c9d1d9" }}>{value}</span>} />
                <Area type="monotone" dataKey="previousBalance" name={data.prevMonthLabel} stroke="#3b82f6" strokeWidth={2} strokeDasharray="6 3" fill="url(#prevGradient)" dot={false} connectNulls />
                <Area type="monotone" dataKey="currentBalance" name={`${MONTHS[now.getMonth()]} ${now.getFullYear()}`} stroke="#22c55e" strokeWidth={3} fill="url(#fundGradient)" dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}

        {chartTab === 4 && (
          <div className="chart-card">
            <h3>Member Payment Status — {MONTHS[now.getMonth()]} {now.getFullYear()}</h3>
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie data={data.paymentStatusData} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={100} label={({name,value}) => `${name}: ${value}`}>
                  {data.paymentStatusData.map((d,i) => <Cell key={i} fill={d.color} />)}
                </Pie>
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend formatter={(value: string) => <span style={{ color:"#c9d1d9" }}>{value}</span>} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}

        {chartTab === 5 && (
          <div className="chart-card">
            <h3>Collection Rate Over Time</h3>
            <ResponsiveContainer width="100%" height={280}>
              <AreaChart data={data.collectionRateTrend}>
                <defs>
                  <linearGradient id="rateGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#f59e0b" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#21262d" />
                <XAxis dataKey="month" stroke="#8b949e" fontSize={11} />
                <YAxis stroke="#8b949e" fontSize={11} tickFormatter={(v: number) => `${v.toFixed(0)}%`} domain={[0, 100]} />
                <Tooltip contentStyle={{ background:"#161b22", border:"1px solid #30363d", borderRadius:8, fontSize:13 }} />
                <Legend formatter={(value: string) => <span style={{ color:"#c9d1d9" }}>{value}</span>} />
                <Area type="monotone" dataKey="rate" name="Collection Rate" stroke="#f59e0b" strokeWidth={3} fill="url(#rateGradient)" dot={{ fill: "#f59e0b", stroke: "#161b22", strokeWidth: 2, r: 4 }} />
              </AreaChart>
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

      {showPendingModal && (
        <div className="modal-overlay" onClick={() => setShowPendingModal(false)}>
          <div className="modal pending-notification-modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 480 }}>
            <div className="modal-header">
              <h2>New Pending Requests</h2>
              <button className="btn-icon" onClick={() => setShowPendingModal(false)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>
            <div className="pending-list" style={{ maxHeight: 320, overflowY: "auto", padding: "0 4px" }}>
              {pendingPaymentsList.length > 0 && (
                <div style={{ marginBottom: 12 }}>
                  <div style={{ fontSize: 11, fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: 1, marginBottom: 6, padding: "0 4px" }}>Payments ({pendingPaymentsList.length})</div>
                  {pendingPaymentsList.map(p => {
                    const memberId = p.memberId as string;
                    const isLoan = p.type === "loan";
                    return (
                    <div key={p.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 10px", background: "#1c2333", borderRadius: 10, marginBottom: 4 }}>
                      <span style={{ fontSize: 16 }}>{isLoan ? "💳" : "💰"}</span>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: 13, fontWeight: 600, color: "#f0f6fc" }}>{data.memberNames[memberId] || memberId}</div>
                        <div style={{ fontSize: 11, color: "#8b949e" }}>{isLoan ? "Loan Repayment" : "Contribution"}</div>
                      </div>
                      <div style={{ fontSize: 13, fontWeight: 700, color: isLoan ? "#3b82f6" : "#22c55e" }}>₱{(Number(p.amount)||0).toLocaleString()}</div>
                    </div>
                    );
                  })}
                </div>
              )}
              {pendingLoansList.length > 0 && (
                <div style={{ marginBottom: 12 }}>
                  <div style={{ fontSize: 11, fontWeight: 600, color: "#3b82f6", textTransform: "uppercase", letterSpacing: 1, marginBottom: 6, padding: "0 4px" }}>Loan Requests ({pendingLoansList.length})</div>
                  {pendingLoansList.map(r => {
                    const memberId = r.memberId as string;
                    const memberName = (r.memberName as string) || data.memberNames[memberId] || memberId;
                    return (
                    <div key={r.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 10px", background: "#1c2333", borderRadius: 10, marginBottom: 4 }}>
                      <span style={{ fontSize: 16 }}>🏦</span>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: 13, fontWeight: 600, color: "#f0f6fc" }}>{memberName}</div>
                        <div style={{ fontSize: 11, color: "#8b949e" }}>Loan</div>
                      </div>
                      <div style={{ fontSize: 13, fontWeight: 700, color: "#3b82f6" }}>₱{(Number(r.amount)||0).toLocaleString()}</div>
                    </div>
                    );
                  })}
                </div>
              )}
              {pendingHeadsList.length > 0 && (
                <div style={{ marginBottom: 12 }}>
                  <div style={{ fontSize: 11, fontWeight: 600, color: "#8b5cf6", textTransform: "uppercase", letterSpacing: 1, marginBottom: 6, padding: "0 4px" }}>Head Changes ({pendingHeadsList.length})</div>
                  {pendingHeadsList.map(h => {
                    const memberId = h.memberId as string;
                    const memberName = (h.memberName as string) || data.memberNames[memberId] || memberId;
                    const currentHeads = Number(h.currentHeads);
                    const requestedHeads = Number(h.requestedHeads);
                    return (
                    <div key={h.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 10px", background: "#1c2333", borderRadius: 10, marginBottom: 4 }}>
                      <span style={{ fontSize: 16 }}>🔄</span>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: 13, fontWeight: 600, color: "#f0f6fc" }}>{memberName}</div>
                        <div style={{ fontSize: 11, color: "#8b949e" }}>{currentHeads} → {requestedHeads} heads</div>
                      </div>
                    </div>
                    );
                  })}
                </div>
              )}
            </div>
            <div className="modal-actions" style={{ borderTop: "1px solid #21262d", paddingTop: 12 }}>
              <button className="btn btn-outline" onClick={() => setShowPendingModal(false)}>Close</button>
              <button className="btn btn-primary" onClick={() => { setShowPendingModal(false); window.location.href = "/admin/approvals"; }}>Open Approvals</button>
            </div>
          </div>
        </div>
      )}
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
