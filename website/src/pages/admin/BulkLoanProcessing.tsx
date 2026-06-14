import React, { useEffect, useState } from "react";
import { collection, writeBatch, doc, getDocs, query, where, limit, Timestamp } from "firebase/firestore";
import { db } from "../../firebase";

interface MemberData {
  id: string;
  name: string;
  memberId?: string;
  active: boolean;
}

const BulkLoanProcessing: React.FC = () => {
  const [members, setMembers] = useState<MemberData[]>([]);
  const [loading, setLoading] = useState(true);
  const [entries, setEntries] = useState<{ memberId: string; principal: string; interestRate: string; dueDate: string }[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<{ success: number; failed: number; failedMembers?: string[] } | null>(null);
  const [quickAmount, setQuickAmount] = useState("");
  const [quickRate, setQuickRate] = useState("5");
  const [quickTermMonths, setQuickTermMonths] = useState("6");

  useEffect(() => {
    getDocs(query(collection(db, "members"), where("active", "==", true)))
      .then(snap => {
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as MemberData));
        setMembers(list);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const addEntry = (memberId: string) => {
    setEntries(prev => [...prev, { memberId, principal: quickAmount || "5000", interestRate: quickRate || "5", dueDate: "" }]);
  };

  const removeEntry = (index: number) => {
    setEntries(prev => prev.filter((_, i) => i !== index));
  };

  const updateEntry = (index: number, field: keyof typeof entries[0], value: string) => {
    setEntries(prev => prev.map((e, i) => i === index ? { ...e, [field]: value } : e));
  };

  const clearAll = () => {
    setEntries([]);
    setResult(null);
  };

  const getMemberName = (id: string) => members.find(m => m.id === id)?.name || id;

  const submitAll = async () => {
    setSubmitting(true);
    const blockedMembers = new Set<string>();
    const failedMembers: string[] = [];

    for (const entry of entries) {
      const name = getMemberName(entry.memberId);
      const principal = parseFloat(entry.principal);
      const rate = parseFloat(entry.interestRate);
      if (!principal || principal <= 0 || !rate || rate <= 0) {
        failedMembers.push(`${name}: invalid amount or rate`);
        blockedMembers.add(entry.memberId);
        continue;
      }
      const activeLoanSnap = await getDocs(query(
        collection(db, "loans"),
        where("memberId", "==", entry.memberId),
        where("isFullyRepaid", "==", false),
        limit(1),
      ));
      if (!activeLoanSnap.empty) {
        failedMembers.push(`${name}: active loan exists`);
        blockedMembers.add(entry.memberId);
      }
    }

    const valid = entries.filter(e => !blockedMembers.has(e.memberId));
    let success = 0;
    let failed = failedMembers.length;

    if (valid.length > 0) {
      const batch = writeBatch(db);
      for (const entry of valid) {
        const principal = parseFloat(entry.principal);
        const rate = parseFloat(entry.interestRate);
        let dueDate: Date;
        if (entry.dueDate) {
          dueDate = new Date(entry.dueDate);
        } else {
          dueDate = new Date();
          dueDate.setMonth(dueDate.getMonth() + (parseInt(quickTermMonths) || 6));
        }
        batch.set(doc(collection(db, "loans")), {
          memberId: entry.memberId,
          principal,
          interestRate: rate / 100,
          issuedDate: Timestamp.now(),
          dueDate: Timestamp.fromDate(dueDate),
          isFullyRepaid: false,
        });
        success++;
      }
      try {
        await batch.commit();
      } catch (err) {
        console.error("Batch commit failed", err);
        failed = valid.length;
        success = 0;
      }
    }

    setResult({ success, failed, failedMembers });
    setSubmitting(false);
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading members...</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Bulk Loan Processing</h1>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginBottom: 12 }}>Quick Defaults</h3>
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          <div className="form-group" style={{ flex: 1, minWidth: 120 }}>
            <label className="form-label">Amount</label>
            <input type="number" className="form-input" value={quickAmount} onChange={e => setQuickAmount(e.target.value)} placeholder="5000" />
          </div>
          <div className="form-group" style={{ flex: 1, minWidth: 120 }}>
            <label className="form-label">Interest Rate (%)</label>
            <input type="number" step="0.1" className="form-input" value={quickRate} onChange={e => setQuickRate(e.target.value)} />
          </div>
          <div className="form-group" style={{ flex: 1, minWidth: 120 }}>
            <label className="form-label">Term (months)</label>
            <input type="number" className="form-input" value={quickTermMonths} onChange={e => setQuickTermMonths(e.target.value)} />
          </div>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginBottom: 12 }}>Select Members</h3>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 16 }}>
          {members.map(m => {
            const alreadyAdded = entries.some(e => e.memberId === m.id);
            return (
              <button
                key={m.id}
                className={`btn btn-sm ${alreadyAdded ? "btn-primary" : "btn-outline"}`}
                onClick={() => alreadyAdded ? removeEntry(entries.findIndex(e => e.memberId === m.id)) : addEntry(m.id)}
                style={{ fontSize: 12 }}
              >
                {alreadyAdded ? "✓ " : "+ "}{m.name || m.id}
              </button>
            );
          })}
        </div>
      </div>

      {entries.length > 0 && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
            <h3>Loan Entries ({entries.length})</h3>
            <button className="btn btn-sm btn-outline-danger" onClick={clearAll}>Clear All</button>
          </div>
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Principal</th>
                  <th>Interest Rate</th>
                  <th>Due Date</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {entries.map((e, i) => (
                  <tr key={i}>
                    <td>{getMemberName(e.memberId)}</td>
                    <td>
                      <input
                        type="number"
                        className="form-input"
                        style={{ width: 100 }}
                        value={e.principal}
                        onChange={v => updateEntry(i, "principal", v.target.value)}
                      />
                    </td>
                    <td>
                      <input
                        type="number"
                        step="0.1"
                        className="form-input"
                        style={{ width: 80 }}
                        value={e.interestRate}
                        onChange={v => updateEntry(i, "interestRate", v.target.value)}
                      />
                    </td>
                    <td>
                      <input
                        type="date"
                        className="form-input"
                        value={e.dueDate}
                        onChange={v => updateEntry(i, "dueDate", v.target.value)}
                      />
                    </td>
                    <td>
                      <button className="btn btn-sm btn-outline-danger" onClick={() => removeEntry(i)}>✕</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <button
            className="btn btn-primary"
            onClick={submitAll}
            disabled={submitting || entries.length === 0}
            style={{ width: "100%", marginTop: 16 }}
          >
            {submitting ? "Processing..." : `Create ${entries.length} Loan${entries.length > 1 ? "s" : ""}`}
          </button>

          {result && (
            <div style={{
              marginTop: 12,
              padding: 12,
              borderRadius: 8,
              background: result.failed > 0 ? "#451a03" : "#064e3b",
              border: `1px solid ${result.failed > 0 ? "#f59e0b" : "#22c55e"}`,
              color: result.failed > 0 ? "#f59e0b" : "#22c55e",
              textAlign: "center",
            }}>
              {result.success} loan{result.success !== 1 ? "s" : ""} created successfully
              {result.failed > 0 && `, ${result.failed} failed`}
              {result.failedMembers && result.failedMembers.length > 0 && (
                <div style={{ marginTop: 4, fontSize: 12, opacity: 0.85 }}>
                  {result.failedMembers.map((m, i) => <div key={i}>{m}</div>)}
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {entries.length === 0 && (
        <div className="card" style={{ textAlign: "center", padding: 32, color: "#6b7280" }}>
          Select members above to add them to the batch. Each entry can be customized before submission.
        </div>
      )}
    </div>
  );
};

export default BulkLoanProcessing;
