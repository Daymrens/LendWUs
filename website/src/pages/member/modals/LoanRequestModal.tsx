import React, { useState, useEffect } from "react";
import {
  collection,
  query,
  where,
  getDocs,
  addDoc,
  Timestamp,
} from "firebase/firestore";
import { db } from "../../../firebase";

interface LoanRequestModalProps {
  memberDocId: string;
  onClose: () => void;
}

const LoanRequestModal: React.FC<LoanRequestModalProps> = ({
  memberDocId, onClose,
}) => {
  const [amount, setAmount] = useState("");
  const [interestRate, setInterestRate] = useState(10);
  const [dueDate, setDueDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() + 30);
    return d.toISOString().split("T")[0];
  });
  const [notes, setNotes] = useState("");
  const [hasContributions, setHasContributions] = useState<boolean | null>(null);
  const [checking, setChecking] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    (async () => {
      const snap = await getDocs(query(collection(db, "contributions"), where("memberId", "==", memberDocId)));
      setHasContributions(!snap.empty);
      setChecking(false);
    })();
  }, [memberDocId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const amt = Number(amount);
    if (!Number.isFinite(amt) || amt <= 0) { alert("Amount must be greater than 0."); return; }
    if (!dueDate) { alert("Please select a due date."); return; }
    setSubmitting(true);
    try {
      await addDoc(collection(db, "loan_requests"), {
        memberId: memberDocId,
        amount: amt,
        interestRate: interestRate / 100,
        dueDate: Timestamp.fromDate(new Date(dueDate)),
        status: "pending",
        requestedAt: Timestamp.now(),
        notes: notes.trim(),
      });
      onClose();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to submit");
    } finally { setSubmitting(false); }
  };

  if (checking) return null;

  if (hasContributions === false) {
    return (
      <div className="modal-overlay" onClick={onClose}>
        <div className="modal" onClick={e => e.stopPropagation()}>
          <div className="modal-header">
            <h2>Request Loan</h2>
            <button className="btn-icon" onClick={onClose}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <div style={{ textAlign: "center", padding: "32px 0" }}>
            <div style={{ fontSize: 48, marginBottom: 16 }}>⚠️</div>
            <h3 style={{ color: "#fff", marginBottom: 8 }}>No Contributions Recorded</h3>
            <p style={{ color: "#8b949e", fontSize: 14, marginBottom: 20 }}>
              You need to make at least one contribution before requesting a loan.
            </p>
            <button className="btn btn-primary" onClick={onClose}>OK</button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Request Loan</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Loan Amount (₱)</label>
            <input type="number" min="0" step="0.01" value={amount} onChange={e => setAmount(e.target.value)} required placeholder="e.g. 5000" />
          </div>
          <div className="form-group">
            <label>Interest Rate (%)</label>
            <input type="number" min="0" max="100" step="0.1" value={interestRate} onChange={e => setInterestRate(Number(e.target.value))} required />
          </div>
          <div className="form-group">
            <label>Due Date</label>
            <input type="date" value={dueDate} onChange={e => setDueDate(e.target.value)} required />
          </div>
          <div className="form-group">
            <label>Purpose / Notes</label>
            <textarea
              value={notes}
              onChange={e => setNotes(e.target.value)}
              required
              rows={3}
              placeholder="What is this loan for?"
              style={{
                width: "100%", padding: "10px 12px",
                background: "#0d1117", border: "1px solid #30363d",
                borderRadius: 8, color: "#c9d1d9", fontSize: 14,
                fontFamily: "inherit", resize: "vertical",
              }}
            />
          </div>
          <div style={{
            background: "rgba(59,130,246,0.1)", border: "1px solid rgba(59,130,246,0.3)",
            borderRadius: 8, padding: 12, marginBottom: 16, fontSize: 12, color: "#8b949e",
          }}>
            <strong style={{ color: "#60a5fa" }}>Important:</strong>
            <ul style={{ margin: "4px 0 0", paddingLeft: 16 }}>
              <li>Your request will be reviewed by admin</li>
              <li>Approval depends on fund availability</li>
              <li>Interest will be added to repayment amount</li>
            </ul>
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-outline" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? "Submitting..." : "Submit Request"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default LoanRequestModal;
