import React, { useState } from "react";
import {
  collection,
  addDoc,
  Timestamp,
  getDocs,
  query,
  where,
} from "firebase/firestore";
import { db } from "../../../firebase";

interface HeadChangeModalProps {
  memberDocId: string;
  currentHeads: number;
  onClose: () => void;
}

const HeadChangeModal: React.FC<HeadChangeModalProps> = ({ memberDocId, currentHeads, onClose }) => {
  const [requestedHeads, setRequestedHeads] = useState(String(currentHeads));
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);

  const requestedNum = Number(requestedHeads);
  const diff = requestedNum - currentHeads;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!Number.isInteger(requestedNum) || requestedNum < 1 || requestedNum > 100) {
      setValidationError("Heads must be between 1 and 100.");
      return;
    }
    if (requestedNum === currentHeads) {
      setValidationError("Requested heads must differ from current heads.");
      return;
    }

    try {
      const now = new Date();
      const isJanuary = now.getMonth() === 0;

      const contribSnap = await getDocs(
        query(collection(db, "contributions"), where("memberId", "==", memberDocId))
      );
      const paymentSnap = await getDocs(
        query(collection(db, "payment_requests"), where("memberId", "==", memberDocId))
      );
      const hasApprovedPayment = paymentSnap.docs.some(
        d => d.data().status === "approved" && d.data().type === "contribution"
      );

      if ((!contribSnap.empty || hasApprovedPayment) && !isJanuary) {
        setValidationError(
          "Head changes for members with existing contributions are only allowed in January (start of the year reset). " +
          "Please wait until January to submit your request.\n\n" +
          "New members with no contributions can change heads at any time."
        );
        return;
      }
    } catch (err) {
      console.error("Head change validation error:", err);
      setValidationError("Could not verify contribution history. Please try again.");
      return;
    }

    setSubmitting(true);
    try {
      await addDoc(collection(db, "head_change_requests"), {
        memberId: memberDocId,
        currentHeads,
        requestedHeads: requestedNum,
        status: "pending",
        requestedAt: Timestamp.now(),
        reason: reason.trim(),
      });
      onClose();
    } catch (err: unknown) {
      setValidationError(err instanceof Error ? err.message : "Failed to submit");
    } finally { setSubmitting(false); }
  };

  return (
    <>
      <div className="modal-overlay" onClick={onClose}>
        <div className="modal" onClick={e => e.stopPropagation()}>
          <div className="modal-header">
            <h2>Change Heads</h2>
            <button className="btn-icon" onClick={onClose}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>

          <div style={{
            display: "flex", alignItems: "center", gap: 12,
            padding: 16, background: "#0d1117", borderRadius: 8,
            marginBottom: 16,
          }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            <div>
              <div style={{ fontSize: 12, color: "#8b949e" }}>Current Heads</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: "#fff" }}>{currentHeads} {currentHeads === 1 ? "head" : "heads"}</div>
            </div>
          </div>

          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label>Requested Heads</label>
              <input
                type="number"
                min="1"
                max="100"
                value={requestedHeads}
                onChange={e => setRequestedHeads(e.target.value)}
                required
              />
            </div>

            {Number.isInteger(requestedNum) && requestedNum >= 1 && requestedNum <= 100 && requestedNum !== currentHeads && (
              <div style={{
                padding: 12, background: "#0d1117", borderRadius: 8, marginBottom: 16,
              }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
                  <span style={{ fontSize: 13, color: "#8b949e" }}>Current: {currentHeads} heads</span>
                  <span style={{ fontSize: 13, color: "#8b949e" }}>Requested: {requestedNum} heads</span>
                </div>
                <div style={{ fontSize: 14, fontWeight: 700, color: diff > 0 ? "#22c55e" : "#ef4444" }}>
                  Difference: {diff > 0 ? "+" : ""}{diff}
                </div>
              </div>
            )}

            <div className="form-group">
              <label>Reason (optional)</label>
              <textarea
                value={reason}
                onChange={e => setReason(e.target.value)}
                rows={2}
                placeholder="Why are you changing your heads?"
                style={{
                  width: "100%", padding: "10px 12px",
                  background: "#0d1117", border: "1px solid #30363d",
                  borderRadius: 8, color: "#c9d1d9", fontSize: 14,
                  fontFamily: "inherit", resize: "vertical",
                }}
              />
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

      {validationError && (
        <div className="modal-overlay" onClick={() => setValidationError(null)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 420 }}>
            <div className="modal-header">
              <h2 style={{ color: "#f59e0b" }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ marginRight: 8, verticalAlign: "middle" }}>
                  <circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>
                </svg>
                Head Change Not Allowed
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

export default HeadChangeModal;
