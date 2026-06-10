import React, { useEffect, useState } from "react";
import {
  collection,
  getDocs,
  updateDoc,
  doc,
  query,
  where,
  orderBy,
  Timestamp,
  limit,
  runTransaction,
  addDoc,
  getDoc,
} from "firebase/firestore";
import { db } from "../../firebase";

interface PaymentRequest {
  id: string;
  memberId: string;
  type: string;
  amount: number;
  status: string;
  requestDate: Timestamp;
  loanId?: string;
  notes?: string;
  rejectReason?: string;
  receiptPath?: string;
}

interface LoanRequest {
  id: string;
  memberId: string;
  memberName: string;
  amount: number;
  interestRate: number;
  dueDate: Timestamp;
  status: string;
  requestedAt: Timestamp;
  notes?: string;
}

interface HeadChangeRequest {
  id: string;
  memberId: string;
  memberName: string;
  currentHeads: number;
  requestedHeads: number;
  status: string;
  requestedAt: Timestamp;
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
        const q = query(collection(db, "payment_requests"), orderBy("requestDate", "desc"));
        const snap = await getDocs(q);
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as PaymentRequest));
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
      const q = query(collection(db, "payment_requests"), orderBy("requestDate", "desc"));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as PaymentRequest));
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
    try {
      const requestRef = doc(db, "payment_requests", req.id);
      let approved = false;

      await runTransaction(db, async (transaction) => {
        const snap = await transaction.get(requestRef);
        if (!snap.exists) throw new Error("Request not found");
        const data = snap.data()!;
        if (data.status !== "pending") throw new Error("Request already processed");

        transaction.update(requestRef, {
          status: "approved",
          approvedDate: Timestamp.now(),
        });
        approved = true;
      });

      if (!approved) return;

      const memberDocId = await resolveMemberDocId(req.memberId);

      if (req.type === "contribution") {
        const now = Timestamp.now();
        const d = now.toDate();
        const month = d.getMonth() + 1;
        const year = d.getFullYear();

        await addDoc(collection(db, "contributions"), {
          memberId: memberDocId,
          amount: req.amount,
          date: now,
          month,
          year,
          createdBy: "member",
        });

        const contribsSnap = await getDocs(query(
          collection(db, "contributions"),
          where("memberId", "==", memberDocId),
          where("month", "==", month),
          where("year", "==", year),
        ));
        let monthTotal = 0;
        contribsSnap.docs.forEach(d => { monthTotal += Number(d.data().amount) || 0; });

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
        await addDoc(collection(db, "repayments"), {
          loanId: req.loanId,
          amountPaid: req.amount,
          date: Timestamp.now(),
        });

        const loanDoc = await getDoc(doc(db, "loans", req.loanId));
        if (loanDoc.exists()) {
          const loan = loanDoc.data();
          const totalDue = (loan.principal || 0) + ((loan.principal || 0) * (loan.interestRate || 0));
          const repaymentsSnap = await getDocs(query(
            collection(db, "repayments"),
            where("loanId", "==", req.loanId),
          ));
          let totalRepaid = 0;
          repaymentsSnap.docs.forEach(d => { totalRepaid += Number(d.data().amountPaid) || 0; });
          if (totalRepaid >= totalDue) {
            await updateDoc(doc(db, "loans", req.loanId), { isFullyRepaid: true });
          }
        }
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
              <p className="approval-date">Submitted: {r.requestDate?.toDate?.()?.toLocaleDateString() || "N/A"}</p>
              {r.notes && <p className="approval-notes">{r.notes}</p>}
              {r.receiptPath && (
                <div style={{ margin: "8px 0" }}>
                  <button className="btn btn-outline btn-sm" onClick={() => setShowReceipt(r.receiptPath!)}>
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

const LoansTab: React.FC = () => {
  const [requests, setRequests] = useState<LoanRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, "loan_requests"), orderBy("requestedAt", "desc"));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as LoanRequest));
      setRequests(list.filter(r => r.status === "pending"));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const handleApprove = async (id: string, request: LoanRequest) => {
    try {
      await runTransaction(db, async (transaction) => {
        const requestRef = doc(db, "loan_requests", id);
        const requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists()) throw new Error("Request not found");
        const data = requestSnap.data();
        if (data.status !== "pending") throw new Error("Request already processed");

        const memberId = data.memberId;

        // Check for existing active loans
        const activeLoansQ = query(
          collection(db, "loans"),
          where("memberId", "==", memberId),
          where("isFullyRepaid", "==", false),
          limit(1)
        );
        const activeLoansSnap = await getDocs(activeLoansQ);
        if (!activeLoansSnap.empty) throw new Error("Member already has an active loan");

        // Create Loan doc
        const loanRef = doc(collection(db, "loans"));
        const interestRate = ((data.interestRate as number) || 0) / 100;
        const dueDate = data.dueDate instanceof Timestamp
          ? data.dueDate
          : data.dueDate?.toDate
            ? Timestamp.fromDate(data.dueDate.toDate())
            : Timestamp.now();

        transaction.set(loanRef, {
          memberId: memberId,
          principal: data.amount,
          interestRate: interestRate,
          issuedDate: Timestamp.now(),
          dueDate: dueDate,
          isFullyRepaid: false,
        });

        // Update request status to disbursed
        transaction.update(requestRef, {
          status: "disbursed",
          processedAt: Timestamp.now(),
          loanId: loanRef.id,
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
                <span>Interest: {r.interestRate || 0}%</span>
                <span>Due: {r.dueDate?.toDate?.()?.toLocaleDateString() || "N/A"}</span>
                <span>Requested: {r.requestedAt?.toDate?.()?.toLocaleDateString() || "N/A"}</span>
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
    </>
  );
};

const HeadsTab: React.FC = () => {
  const [requests, setRequests] = useState<HeadChangeRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, "head_change_requests"), orderBy("requestedAt", "desc"));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as HeadChangeRequest));
      setRequests(list.filter(r => r.status === "pending"));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const handleApprove = async (id: string) => {
    try {
      await updateDoc(doc(db, "head_change_requests", id), {
        status: "approved",
        processedAt: Timestamp.now(),
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
                    <span>{r.currentHeads} heads</span>
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                    <span style={{ color: "#f59e0b" }}>{r.requestedHeads} heads</span>
                  </div>
                </div>
                <span className={`${r.requestedHeads > r.currentHeads ? "text-success" : "text-error"}`}>
                  {r.requestedHeads > r.currentHeads ? "+" : ""}{r.requestedHeads - r.currentHeads}
                </span>
              </div>
              <div className="approval-details">
                <span>Current: {r.currentHeads}</span>
                <span>Requested: {r.requestedHeads}</span>
                <span>Requested: {r.requestedAt?.toDate?.()?.toLocaleDateString() || "N/A"}</span>
              </div>
              {r.reason && <p className="approval-notes">Reason: {r.reason}</p>}
              <div className="approval-actions">
                <button className="btn btn-outline btn-sm" style={{ color: "#ef4444", borderColor: "#ef4444" }} onClick={() => handleReject(r.id)}>
                  Reject
                </button>
                <button className="btn btn-primary btn-sm" style={{ background: "#22c55e" }} onClick={() => handleApprove(r.id)}>
                  Approve
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
};

export default Approvals;
