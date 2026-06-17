import React, { useEffect, useState } from "react";
import {
  collection,
  getDocs,
  updateDoc,
  doc,
  query,
  where,
  Timestamp,
  limit,
  runTransaction,
  addDoc,
  writeBatch,
  getDoc,
} from "firebase/firestore";
import { db } from "../../firebase";

interface PaymentRequest {
  id: string;
  memberId: string;
  amount: number;
  status: string;
  type?: string;
  createdAt?: Timestamp;
  loanId?: string;
  notes?: string;
  rejectReason?: string;
  receiptPath?: string;
  receiptUrl?: string;
}

interface LoanRequest {
  id: string;
  memberId: string;
  memberName?: string;
  amount?: number;
  principal?: number;
  interestRate: number;
  dueDate: Timestamp;
  status: string;
  createdAt?: Timestamp;
  notes?: string;
}

interface HeadChangeRequest {
  id: string;
  memberId: string;
  memberName?: string;
  currentHeads?: number;
  requestedHeads: number;
  status: string;
  createdAt?: Timestamp;
  reason?: string;
}

const Approvals: React.FC = () => {
  const [tab, setTab] = useState(0);

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Pending Approvals</h1>
      </div>
      <div className="tabs">
        {["Payments", "Loans", "Heads"].map((t, i) => (
          <button key={t} className={`tab ${i === tab ? "active" : ""}`} onClick={() => setTab(i)}>
            {t}
          </button>
        ))}
      </div>
      {tab === 0 && <PaymentsTab />}
      {tab === 1 && <LoansTab />}
      {tab === 2 && <HeadsTab />}
    </div>
  );
};

const PaymentsTab: React.FC = () => {
  const [requests, setRequests] = useState<PaymentRequest[]>([]);
  const [memberNames, setMemberNames] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [showReceipt, setShowReceipt] = useState<string | null>(null);

  const loadNames = async () => {
    const snap = await getDocs(collection(db, "members"));
    const names: Record<string, string> = {};
    snap.docs.forEach(d => { names[d.id] = d.data().name || d.id; });
    return names;
  };

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const snap = await getDocs(collection(db, "payment_requests"));
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as PaymentRequest));
        list.sort((a, b) => {
          const da = a.createdAt?.toDate?.() ?? new Date(0);
          const db = b.createdAt?.toDate?.() ?? new Date(0);
          return db.getTime() - da.getTime();
        });
        setRequests(list.filter(r => r.status === "pending"));
        const names = await loadNames();
        setMemberNames(names);
      } catch { /* ignore */ }
      finally { setLoading(false); }
    })();
  }, []);

  const reload = async () => {
    setLoading(true);
    try {
      const snap = await getDocs(collection(db, "payment_requests"));
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as PaymentRequest));
      list.sort((a, b) => {
        const da = a.createdAt?.toDate?.() ?? new Date(0);
        const db = b.createdAt?.toDate?.() ?? new Date(0);
        return db.getTime() - da.getTime();
      });
      setRequests(list.filter(r => r.status === "pending"));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  const resolveMemberDocId = async (memberId: string): Promise<string> => {
    const direct = await getDoc(doc(db, "members", memberId));
    if (direct.exists()) return memberId;
    const byDisplay = await getDocs(query(collection(db, "members"), where("memberId", "==", memberId), limit(1)));
    if (!byDisplay.empty) return byDisplay.docs[0].id;
    return memberId;
  };

  const handleApprove = async (req: PaymentRequest) => {
    if (!window.confirm(`Approve this ${req.type === "contribution" ? "contribution" : "repayment"} payment of ₱${req.amount.toLocaleString()}? This will record the payment and cannot be undone.`)) return;
    try {
      const requestRef = doc(db, "payment_requests", req.id);
      const memberDocId = await resolveMemberDocId(req.memberId);
      const now = Timestamp.now();
      const d = now.toDate();
      const month = d.getMonth() + 1;
      const year = d.getFullYear();

      if (req.type === "contribution") {
        await runTransaction(db, async (transaction) => {
          const snap = await transaction.get(requestRef);
          if (!snap.exists) throw new Error("Request not found");
          const data = snap.data()!;
          if (data.status !== "pending") throw new Error("Request already processed");

          transaction.update(requestRef, {
            status: "approved",
            approvedDate: now,
          });

          const contribData: Record<string, unknown> = {
            memberId: memberDocId,
            amount: req.amount,
            date: now,
            month,
            year,
            createdBy: "member",
          };
          if (req.receiptUrl) contribData.receiptUrl = req.receiptUrl;
          const contribRef = doc(collection(db, "contributions"));
          transaction.set(contribRef, contribData);
        });

        const contribsSnap = await getDocs(
          query(collection(db, "contributions"), where("memberId", "==", memberDocId))
        );
        const monthStart = new Date(year, month - 1, 1);
        const monthEnd = new Date(year, month, 0, 23, 59, 59, 999);
        let monthTotal = 0;
        contribsSnap.docs.forEach(d => {
          const cd = d.data().date?.toDate?.();
          if (cd && cd >= monthStart && cd <= monthEnd) {
            monthTotal += Number(d.data().amount) || 0;
          }
        });

        const memberDoc = await getDoc(doc(db, "members", memberDocId));
        if (memberDoc.exists()) {
          const memberData = memberDoc.data();
          const required = Number(memberData.totalRequired) || 0;
          const currentBalance = Number(memberData.balance) || 0;

          if (monthTotal > required) {
            const excess = monthTotal - required;
            await updateDoc(doc(db, "members", memberDocId), {
              balance: currentBalance + excess,
            });
          } else if (monthTotal < required && currentBalance > 0) {
            const needed = required - monthTotal;
            const toApply = currentBalance >= needed ? needed : currentBalance;
            if (toApply > 0) {
              await addDoc(collection(db, "contributions"), {
                memberId: memberDocId,
                amount: toApply,
                date: now,
                month,
                year,
                notes: "Applied from balance",
                createdBy: "system",
              });
              await updateDoc(doc(db, "members", memberDocId), {
                balance: currentBalance - toApply,
              });
            }
          }
        }
      } else if (req.type === "loan" && req.loanId) {
        await runTransaction(db, async (transaction) => {
          const snap = await transaction.get(requestRef);
          if (!snap.exists) throw new Error("Request not found");
          const data = snap.data()!;
          if (data.status !== "pending") throw new Error("Request already processed");

          const loanSnap = await transaction.get(doc(db, "loans", req.loanId!));
          if (!loanSnap.exists) throw new Error("Loan not found");
          const loanData = loanSnap.data()!;
          const totalDue = (loanData.principal || 0) + ((loanData.principal || 0) * (loanData.interestRate || 0));

          transaction.update(requestRef, {
            status: "approved",
            approvedDate: now,
          });

          const repayRef = doc(collection(db, "repayments"));
          transaction.set(repayRef, {
            loanId: req.loanId,
            amountPaid: req.amount,
            date: now,
          });

          const repaymentsSnap = await getDocs(query(
            collection(db, "repayments"),
            where("loanId", "==", req.loanId),
          ));
          let totalRepaid = req.amount;
          repaymentsSnap.docs.forEach(d => { totalRepaid += Number(d.data().amountPaid) || 0; });
          if (totalRepaid >= totalDue) {
            transaction.update(doc(db, "loans", req.loanId!), { isFullyRepaid: true });
          }
        });
      }

      reload();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to approve");
    }
  };

  const handleReject = async (id: string) => {
    const reason = window.prompt("Reason for rejection (optional):");
    if (reason === null) return;
    try {
      await updateDoc(doc(db, "payment_requests", id), {
        status: "rejected",
        rejectReason: reason || "",
        approvedDate: Timestamp.now(),
      });
      reload();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to reject");
    }
  };

  const filtered = requests.filter(r => {
    if (!search) return true;
    const q = search.toLowerCase();
    const name = memberNames[r.memberId] || "";
    return name.toLowerCase().includes(q) || (r.notes || "").toLowerCase().includes(q) || String(r.amount).includes(q);
  });

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;

  return (
    <>
      <input
        type="text"
        placeholder="Search by member, amount, notes..."
        value={search}
        onChange={e => setSearch(e.target.value)}
        className="search-input"
        style={{ marginTop: 16 }}
      />
      {filtered.length === 0 ? <p className="empty-text">No pending payments</p> : (
        <div className="approvals-list">
          {filtered.map(r => (
            <div key={r.id} className="approval-card">
              <div className="approval-top">
                <div>
                  <strong>{memberNames[r.memberId] || r.memberId}</strong>
                  <span className={`badge badge-${r.type === "loan" ? "orange" : "blue"}`} style={{ marginLeft: 8 }}>
                    {r.type === "loan" ? "Loan Repayment" : "Contribution"}
                  </span>
                </div>
                <span className="approval-amount">₱{(r.amount || 0).toLocaleString()}</span>
              </div>
              <p className="approval-date">Submitted: {r.createdAt?.toDate?.()?.toLocaleDateString() || "N/A"}</p>
              {r.notes && <p className="approval-notes">{r.notes}</p>}
              {(r.receiptPath || r.receiptUrl) && (
                <div style={{ margin: "8px 0" }}>
                  <button className="btn btn-outline btn-sm" onClick={() => setShowReceipt(r.receiptPath || r.receiptUrl || "")}>
                    View Receipt
                  </button>
                </div>
              )}
              <div className="approval-actions">
                <button className="btn btn-outline btn-sm" style={{ color: "#ef4444", borderColor: "#ef4444" }} onClick={() => handleReject(r.id)}>
                  Reject
                </button>
                <button className="btn btn-primary btn-sm" style={{ background: "#22c55e" }} onClick={() => handleApprove(r)}>
                  Approve
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
      {showReceipt && (
        <div className="modal-overlay" onClick={() => setShowReceipt(null)}>
          <div className="receipt-modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Receipt</h2>
              <button className="btn-icon" onClick={() => setShowReceipt(null)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>
            <img src={showReceipt} alt="Receipt" style={{ maxWidth: "100%", maxHeight: "70vh", borderRadius: 8, objectFit: "contain" }} />
          </div>
        </div>
      )}
    </>
  );
};

interface LoanReceipt {
  id: string;
  loanId: string;
  receiptNumber: string;
  memberName: string;
  principal: number;
  interestRate: number;
  interestAmount: number;
  totalAmountDue: number;
  issuedDate: Timestamp;
  dueDate: Timestamp;
  status: string;
  copyFor: string;
  generatedAt: Timestamp;
}

const LoansTab: React.FC = () => {
  const [requests, setRequests] = useState<LoanRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [viewLoanReceipt, setViewLoanReceipt] = useState<LoanReceipt | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      const snap = await getDocs(collection(db, "loan_requests"));
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as LoanRequest));
      list.sort((a, b) => {
        const da = a.createdAt?.toDate?.() ?? new Date(0);
        const db = b.createdAt?.toDate?.() ?? new Date(0);
        return db.getTime() - da.getTime();
      });
      setRequests(list.filter(r => r.status === "pending"));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const handleApprove = async (id: string, request: LoanRequest) => {
    if (!window.confirm(`Approve loan of ₱${(request.amount || 0).toLocaleString()} for ${request.memberName || request.memberId}? This will disburse the loan and generate a receipt.`)) return;
    let loanRefId = "";
    try {
      let memberId = "";
      let principal = 0;
      let interestRate = 0;
      let dueDate: Timestamp = Timestamp.now();

      // Check available funds before approving
      const principalAmount = request.amount || 0;
      if (principalAmount > 0) {
        const [contribSnap, loanSnap, repaySnap] = await Promise.all([
          getDocs(collection(db, "contributions")),
          getDocs(collection(db, "loans")),
          getDocs(collection(db, "repayments")),
        ]);
        let totalContributions = 0;
        contribSnap.docs.forEach(d => { totalContributions += Number(d.data().amount) || 0; });
        let totalLoansIssued = 0;
        let outstandingBalance = 0;
        loanSnap.docs.forEach(d => {
          const p = Number(d.data().principal) || 0;
          totalLoansIssued += p;
          if (d.data().isFullyRepaid === false) outstandingBalance += p;
        });
        let totalRepayments = 0;
        repaySnap.docs.forEach(d => { totalRepayments += Number(d.data().amountPaid) || 0; });
        const totalAmountDuePerLoan = (l: any) => {
          const p = Number(l.principal) || 0;
          const r = Number(l.interestRate) || 0;
          return p + (p * r);
        };
        let remainingBalanceSum = 0;
        loanSnap.docs.forEach(d => {
          if (d.data().isFullyRepaid === false) {
            const loanId = d.id;
            const totalDue = totalAmountDuePerLoan(d.data());
            let repaid = 0;
            repaySnap.docs.forEach(r => {
              if (r.data().loanId === loanId) repaid += Number(r.data().amountPaid) || 0;
            });
            remainingBalanceSum += Math.max(0, totalDue - repaid);
          }
        });
        const fundBalance = totalContributions - totalLoansIssued + totalRepayments;
        const availableToLoan = fundBalance - remainingBalanceSum;

        if (principalAmount > availableToLoan) {
          const reason = "Insufficient fund balance — the fund does not have enough available cash to cover this loan. Please wait for more contributions to come in before re-applying.";
          await updateDoc(doc(db, "loan_requests", id), {
            status: "rejected",
            notes: reason,
            processedAt: Timestamp.now(),
          });
          alert(`Loan request rejected.\n\nReason: ${reason}`);
          load();
          return;
        }
      }

      await runTransaction(db, async (transaction) => {
        const requestRef = doc(db, "loan_requests", id);
        const requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists()) throw new Error("Request not found");
        const data = requestSnap.data();
        if (data.status !== "pending") throw new Error("Request already processed");

        memberId = data.memberId;

        interestRate = ((data.interestRate as number) || 0) / 100;
        principal = data.amount;
        dueDate = data.dueDate instanceof Timestamp
          ? data.dueDate
          : data.dueDate?.toDate
            ? Timestamp.fromDate(data.dueDate.toDate())
            : Timestamp.now();

        const existingLoanSnap = await getDocs(query(
          collection(db, "loans"),
          where("memberId", "==", memberId),
          where("isFullyRepaid", "==", false),
          limit(1)
        ));
        for (const existingDoc of existingLoanSnap.docs) {
          const existingRef = doc(db, "loans", existingDoc.id);
          const refreshed = await transaction.get(existingRef);
          const loanData = refreshed.data();
          if (loanData && loanData.isFullyRepaid === false) {
            throw new Error("Member already has an active loan");
          }
        }

        const loanRef = doc(collection(db, "loans"));
        loanRefId = loanRef.id;

        transaction.set(loanRef, {
          memberId: memberId,
          principal: principal,
          interestRate: interestRate,
          issuedDate: Timestamp.now(),
          dueDate: dueDate,
          isFullyRepaid: false,
        });

        transaction.update(requestRef, {
          status: "disbursed",
          processedAt: Timestamp.now(),
          loanId: loanRef.id,
        });
      });

      // Generate loan receipts
      if (loanRefId && memberId) {
        const memberSnap = await getDoc(doc(db, "members", memberId));
        const memberName = memberSnap.exists() ? (memberSnap.data().name || memberId) : memberId;
        const now = Timestamp.now();
        const receiptNumber = `LR-${now.toDate().getFullYear()}${String(now.toDate().getMonth() + 1).padStart(2, "0")}-${String(now.toDate().getTime() % 100000).padStart(5, "0")}`;
        const interestAmount = principal * interestRate;
        const totalAmountDue = principal + interestAmount;

        const adminRef = doc(collection(db, "loan_receipts"));
        const borrowerRef = doc(collection(db, "loan_receipts"));
        const adminData = {
          loanId: loanRefId,
          receiptNumber,
          memberId,
          memberName,
          principal,
          interestRate,
          interestAmount,
          totalAmountDue,
          issuedDate: Timestamp.now(),
          dueDate,
          status: "active",
          copyFor: "admin",
          generatedAt: now,
        };
        const borrowerData = {
          loanId: loanRefId,
          receiptNumber,
          memberId,
          memberName,
          principal,
          interestRate,
          interestAmount,
          totalAmountDue,
          issuedDate: Timestamp.now(),
          dueDate,
          status: "active",
          copyFor: "borrower",
          generatedAt: now,
        };

        const batch = writeBatch(db);
        batch.set(adminRef, adminData);
        batch.set(borrowerRef, borrowerData);
        await batch.commit();

        // Auto-pop receipt for admin
        setViewLoanReceipt({ id: adminRef.id, ...adminData } as LoanReceipt);
      }

      load();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to approve");
    }
  };

  const handleReject = async (id: string) => {
    const reason = window.prompt("Reason for rejection (optional):");
    if (reason === null) return;
    try {
      await updateDoc(doc(db, "loan_requests", id), {
        status: "rejected",
        notes: reason || "",
        processedAt: Timestamp.now(),
      });
      load();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to reject");
    }
  };

  const filtered = requests.filter(r => {
    if (!search) return true;
    const q = search.toLowerCase();
    const name = (r.memberName || "").toLowerCase();
    return name.includes(q) || String(r.amount).includes(q) || (r.notes || "").toLowerCase().includes(q);
  });

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;

  return (
    <>
      <input
        type="text"
        placeholder="Search by member, amount..."
        value={search}
        onChange={e => setSearch(e.target.value)}
        className="search-input"
        style={{ marginTop: 16 }}
      />
      {filtered.length === 0 ? <p className="empty-text">No pending loan requests</p> : (
        <div className="approvals-list">
          {filtered.map(r => (
            <div key={r.id} className="approval-card">
              <div className="approval-top">
                <div>
                  <strong>{r.memberName || r.memberId}</strong>
                </div>
                <span className="approval-amount" style={{ color: "#f59e0b" }}>₱{(r.amount || 0).toLocaleString()}</span>
              </div>
              <div className="approval-details">
                <span>Interest: {r.interestRate > 1 ? r.interestRate : ((r.interestRate || 0) * 100).toFixed(1)}%</span>
                <span>Due: {r.dueDate?.toDate?.()?.toLocaleDateString() || "N/A"}</span>
                <span>Requested: {r.createdAt?.toDate?.()?.toLocaleDateString() || "N/A"}</span>
              </div>
              {r.notes && <p className="approval-notes">Notes: {r.notes}</p>}
              <div className="approval-actions">
                <button className="btn btn-outline btn-sm" style={{ color: "#ef4444", borderColor: "#ef4444" }} onClick={() => handleReject(r.id)}>
                  Reject
                </button>
                <button className="btn btn-primary btn-sm" style={{ background: "#22c55e" }} onClick={() => handleApprove(r.id, r)}>
                  Approve
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Loan Receipt Modal — auto-pops after approval */}
      {viewLoanReceipt && (
        <div className="modal-overlay" onClick={() => setViewLoanReceipt(null)}>
          <div className="modal receipt-modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 520 }}>
            <div className="modal-header no-print">
              <h2>Loan Receipt</h2>
              <button className="btn-icon" onClick={() => setViewLoanReceipt(null)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>

            <div className="receipt-print-area">
              <div style={{ textAlign: "center", marginBottom: 16 }}>
                <div className="receipt-logo">
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ marginBottom: 4 }}>
                    <rect x="2" y="5" width="20" height="14" rx="2"/>
                    <line x1="2" y1="10" x2="22" y2="10"/>
                    <circle cx="12" cy="15" r="1"/>
                  </svg>
                  <span className="receipt-logo-text">Lend<span>WUs</span></span>
                </div>
                <div className="receipt-subtitle">Group Sinking Fund — Official Loan Receipt</div>
              </div>

              <div className="receipt-divider" />

              <div className="receipt-number-row">
                <span className="receipt-number-label">Receipt No.</span>
                <span className="receipt-number-value">{viewLoanReceipt.receiptNumber}</span>
              </div>

              <div className="receipt-amount-box">
                <div className="receipt-amount">₱{viewLoanReceipt.totalAmountDue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</div>
                <div className="receipt-amount-label">Total Amount Due</div>
              </div>

              <div className="receipt-divider" />

              <table className="receipt-table">
                <tbody>
                  <tr><td className="receipt-label">Member</td><td className="receipt-value">{viewLoanReceipt.memberName}</td></tr>
                  <tr><td className="receipt-label">Principal</td><td className="receipt-value">₱{viewLoanReceipt.principal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr>
                  <tr><td className="receipt-label">Interest Rate</td><td className="receipt-value">{(viewLoanReceipt.interestRate * 100).toFixed(1)}%</td></tr>
                  <tr><td className="receipt-label">Interest Amount</td><td className="receipt-value">₱{viewLoanReceipt.interestAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td></tr>
                  <tr className="receipt-spacer"><td colSpan={2}></td></tr>
                  <tr><td className="receipt-label">Issue Date</td><td className="receipt-value">{viewLoanReceipt.issuedDate?.toDate?.()?.toLocaleDateString() || "N/A"}</td></tr>
                  <tr><td className="receipt-label">Due Date</td><td className="receipt-value">{viewLoanReceipt.dueDate?.toDate?.()?.toLocaleDateString() || "N/A"}</td></tr>
                  <tr><td className="receipt-label">Status</td><td className="receipt-value">{viewLoanReceipt.status.toUpperCase()}</td></tr>
                  <tr><td className="receipt-label">Generated</td><td className="receipt-value">{viewLoanReceipt.generatedAt?.toDate?.()?.toLocaleDateString() || "N/A"}</td></tr>
                </tbody>
              </table>

              <div className="receipt-divider" />

              <div className="receipt-footer">
                <p>This is a computer-generated receipt. No signature required.</p>
                <p className="receipt-thankyou">Thank you for being a part of LendWUs!</p>
              </div>
            </div>

            <div className="modal-actions no-print">
              <button className="btn btn-outline" onClick={() => setViewLoanReceipt(null)}>Close</button>
              <button className="btn btn-primary" onClick={() => window.print()}>🖨️ Print</button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

const HeadsTab: React.FC = () => {
  const [requests, setRequests] = useState<HeadChangeRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [validationError, setValidationError] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      const snap = await getDocs(collection(db, "head_change_requests"));
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as HeadChangeRequest));
      list.sort((a, b) => {
        const da = a.createdAt?.toDate?.() ?? new Date(0);
        const db = b.createdAt?.toDate?.() ?? new Date(0);
        return db.getTime() - da.getTime();
      });
      setRequests(list.filter(r => r.status === "pending"));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const handleApprove = async (id: string, memberId: string, currentHeads?: number, requestedHeads?: number) => {
    if (!window.confirm(`Approve head change from ${currentHeads || "?"} to ${requestedHeads || "?"} heads? This takes effect immediately.`)) return;
    try {
      const now = new Date();
      const isJanuary = now.getMonth() === 0;

      const contribSnap = await getDocs(
        query(collection(db, "contributions"), where("memberId", "==", memberId))
      );
      const paymentSnap = await getDocs(
        query(collection(db, "payment_requests"), where("memberId", "==", memberId))
      );
      const hasApprovedPayment = paymentSnap.docs.some(
        d => d.data().status === "approved" && d.data().type === "contribution"
      );

      if ((!contribSnap.empty || hasApprovedPayment) && !isJanuary) {
        setValidationError(
          "This member has existing contributions. Head changes are only allowed in January (start of the year reset)."
        );
        return;
      }
    } catch (err) {
      console.error("Head change validation error:", err);
      setValidationError("Could not verify contribution history. Please try again.");
      return;
    }

    try {
      await runTransaction(db, async (transaction) => {
        const requestRef = doc(db, "head_change_requests", id);
        const requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists()) throw new Error("Request not found");
        if (requestSnap.data().status !== "pending") throw new Error("Request already processed");

        transaction.update(requestRef, {
          status: "approved",
          processedAt: Timestamp.now(),
        });

        const memberRef = doc(db, "members", memberId);
        transaction.update(memberRef, {
          headsCount: requestedHeads,
        });
      });
      load();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to approve");
    }
  };

  const handleReject = async (id: string) => {
    const reason = window.prompt("Reason for rejection (optional):");
    if (reason === null) return;
    try {
      await updateDoc(doc(db, "head_change_requests", id), {
        status: "rejected",
        notes: reason || "",
        processedAt: Timestamp.now(),
      });
      load();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to reject");
    }
  };

  const filtered = requests.filter(r => {
    if (!search) return true;
    const q = search.toLowerCase();
    const name = (r.memberName || "").toLowerCase();
    return name.includes(q) || (r.reason || "").toLowerCase().includes(q);
  });

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;

  return (
    <>
      <input
        type="text"
        placeholder="Search by member, reason..."
        value={search}
        onChange={e => setSearch(e.target.value)}
        className="search-input"
        style={{ marginTop: 16 }}
      />
      {filtered.length === 0 ? <p className="empty-text">No pending head change requests</p> : (
        <div className="approvals-list">
          {filtered.map(r => (
            <div key={r.id} className="approval-card">
              <div className="approval-top">
                <div>
                  <strong>{r.memberName || r.memberId}</strong>
                  <div className="head-change-display">
                    <span>{r.currentHeads ?? 0} heads</span>
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                    <span style={{ color: "#f59e0b" }}>{r.requestedHeads} heads</span>
                  </div>
                </div>
                <span className={`${r.requestedHeads > (r.currentHeads ?? 0) ? "text-success" : "text-error"}`}>
                  {r.requestedHeads > (r.currentHeads ?? 0) ? "+" : ""}{r.requestedHeads - (r.currentHeads ?? 0)}
                </span>
              </div>
              <div className="approval-details">
                <span>Current: {r.currentHeads ?? 0}</span>
                <span>Requested: {r.requestedHeads}</span>
                <span>Date: {r.createdAt?.toDate?.()?.toLocaleDateString() || "N/A"}</span>
              </div>
              {r.reason && <p className="approval-notes">Reason: {r.reason}</p>}
              <div className="approval-actions">
                <button className="btn btn-outline btn-sm" style={{ color: "#ef4444", borderColor: "#ef4444" }} onClick={() => handleReject(r.id)}>
                  Reject
                </button>
                <button className="btn btn-primary btn-sm" style={{ background: "#22c55e" }} onClick={() => handleApprove(r.id, r.memberId, r.currentHeads, r.requestedHeads)}>
                  Approve
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {validationError && (
        <div className="modal-overlay" onClick={() => setValidationError(null)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 420 }}>
            <div className="modal-header">
              <h2 style={{ color: "#f59e0b" }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ marginRight: 8, verticalAlign: "middle" }}>
                  <circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>
                </svg>
                Cannot Approve
              </h2>
            </div>
            <div style={{ padding: "8px 24px 24px", color: "#8b949e", lineHeight: 1.6, fontSize: 14, whiteSpace: "pre-line" }}>
              {validationError}
            </div>
            <div className="modal-actions">
              <button className="btn btn-primary" onClick={() => setValidationError(null)}>OK</button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default Approvals;
