import React, { useState, useEffect } from "react";
import {
  collection,
  query,
  where,
  onSnapshot,
  addDoc,
  Timestamp,
  doc,
  getDoc,
} from "firebase/firestore";
import { db } from "../../../firebase";
import { compressImage } from "../../../utils/image";

interface PaymentModalProps {
  memberId: string;
  memberDocId: string;
  memberName: string;
  headsCount: number;
  totalRequired: number;
  balance: number;
  onClose: () => void;
  defaultAdvance?: boolean;
}

interface QRSettings {
  qrAccountName: string;
  qrAccountNumber: string;
  qrImageUrl: string;
}

const formatCurrency = (n: number) =>
  n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const PaymentModal: React.FC<PaymentModalProps> = ({
  memberId, memberDocId, memberName, headsCount, totalRequired, balance, onClose, defaultAdvance,
}) => {
  const [receiptFile, setReceiptFile] = useState<File | null>(null);
  const [receiptPreview, setReceiptPreview] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [thisMonthContribs, setThisMonthContribs] = useState<number>(0);
  const [showQR, setShowQR] = useState(false);
  const [qrSettings, setQRSettings] = useState<QRSettings>({ qrAccountName: "", qrAccountNumber: "", qrImageUrl: "" });

  useEffect(() => {
    getDoc(doc(db, "app_settings", "fund_settings")).then(snap => {
      if (snap.exists()) {
        const d = snap.data();
        setQRSettings({
          qrAccountName: d.qrAccountName || "",
          qrAccountNumber: d.qrAccountNumber || "",
          qrImageUrl: d.qrImageUrl || "",
        });
      }
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (!memberDocId) return;
    const now = new Date();
    const unsub = onSnapshot(
      query(collection(db, "contributions"), where("memberId", "==", memberDocId)),
      (snap) => {
        let total = 0;
        snap.docs.forEach(d => {
          const c = d.data();
          const date = c.date?.toDate?.();
          if (date && date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear()) {
            total += Number(c.amount) || 0;
          }
        });
        setThisMonthContribs(total);
      }
    );
    return unsub;
  }, [memberDocId]);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setReceiptFile(file);
      try {
        const compressed = await compressImage(file);
        setReceiptPreview(compressed);
      } catch {
        const reader = new FileReader();
        reader.onloadend = () => setReceiptPreview(reader.result as string);
        reader.readAsDataURL(file);
      }
    }
  };

  const removeReceipt = () => {
    setReceiptFile(null);
    setReceiptPreview(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const amt = Number(amount);
    if (!Number.isFinite(amt) || amt <= 0) { alert("Amount must be greater than 0."); return; }
    if (!receiptFile) { alert("Please upload a receipt photo."); return; }
    setSubmitting(true);
      try {
      const d = new Date();
      const receiptData = receiptPreview || "";
      await addDoc(collection(db, "payment_requests"), {
        memberId: memberDocId,
        amount: amt,
        type: "contribution",
        status: "pending",
        requestDate: Timestamp.now(),
        month: d.getMonth() + 1,
        year: d.getFullYear(),
        notes: "",
        receiptPath: receiptData,
        receiptUrl: receiptData,
        receiptFilename: receiptFile.name,
      });
      onClose();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to submit");
    } finally { setSubmitting(false); }
  };

  const perCutoffAmount = totalRequired / 2;
  const perHeadAmount = totalRequired / headsCount;
  const remaining = totalRequired - thisMonthContribs;
  const met = thisMonthContribs >= totalRequired;
  const initialAdvance = defaultAdvance ?? (!met && thisMonthContribs > 0);
  const [payAdvance, setPayAdvance] = useState(initialAdvance);
  const [amount, setAmount] = useState(initialAdvance ? String(perCutoffAmount) : String(totalRequired));

  useEffect(() => {
    if (defaultAdvance === undefined) {
      setPayAdvance(!met);
      if (!met) setAmount(String(totalRequired));
      else setAmount(String(perCutoffAmount));
    }
  }, [met, totalRequired, perCutoffAmount, defaultAdvance]);

  const quickAmounts = payAdvance
    ? [50, 75, 100, 125].map(pct => (perCutoffAmount * pct) / 100)
    : met
      ? [50, 75, 100, 125].map(pct => (totalRequired * pct) / 100)
      : [25, 50, 75, 100].map(pct => (totalRequired * pct) / 100);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 520 }}>
        <div className="modal-header">
          <h2>Pay Contribution</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>

        <div className="settings-section" style={{ marginBottom: 16 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 12 }}>
            <div style={{
              width: 40, height: 40, borderRadius: "50%",
              background: "rgba(34,197,94,0.1)", display: "flex",
              alignItems: "center", justifyContent: "center",
              fontWeight: 700, fontSize: 16, color: "#22c55e",
            }}>
              {memberName.charAt(0).toUpperCase()}
            </div>
            <div>
              <div style={{ fontWeight: 600, color: "#fff" }}>{memberName}</div>
              <div style={{ fontSize: 12, color: "#8b949e" }}>Member</div>
            </div>
          </div>

          <div className="chart-card" style={{ marginBottom: 12 }}>
            <div style={{ fontSize: 12, color: "#8b949e", marginBottom: 8 }}>
              {payAdvance
                ? `Next Cutoff: ₱0 / ₱${formatCurrency(perCutoffAmount)}`
                : `This Month: ₱${formatCurrency(thisMonthContribs)} / ₱${formatCurrency(totalRequired)}`}
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
              <span style={{ fontSize: 13, color: met ? "#22c55e" : "#f59e0b" }}>
                ₱{formatCurrency(payAdvance ? 0 : thisMonthContribs)}
              </span>
              <span style={{ fontSize: 12, color: "#8b949e" }}>
                {payAdvance
                  ? `₱${formatCurrency(perCutoffAmount)} (next cutoff)`
                  : `₱${formatCurrency(totalRequired)} (₱${formatCurrency(perHeadAmount)}/head × ${headsCount})`}
              </span>
            </div>
            <div style={{ height: 8, background: "#1c2128", borderRadius: 4, overflow: "hidden" }}>
              <div style={{
                width: `${payAdvance ? 0 : Math.min((thisMonthContribs / totalRequired) * 100, 100)}%`,
                height: "100%", background: met ? "#22c55e" : "#f59e0b",
                borderRadius: 4,
              }} />
            </div>
            {met ? (
              <div style={{ marginTop: 6, fontSize: 12, color: "#22c55e", fontWeight: 600 }}>
                ✓ Requirement met for this month
              </div>
            ) : (
              <div style={{ marginTop: 6, fontSize: 12, color: "#f59e0b", fontWeight: 600 }}>
                ₱{formatCurrency(remaining)} remaining this month
              </div>
            )}
          </div>

          {balance > 0 && (
            <div style={{ marginBottom: 12, fontSize: 13, color: "#22c55e", fontWeight: 600, display: "flex", alignItems: "center", gap: 6 }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/></svg>
              Credit balance: ₱{formatCurrency(balance)}
            </div>
          )}
        </div>

        {met && !payAdvance ? (
          <div style={{
            background: "linear-gradient(135deg, rgba(34,197,94,0.12), rgba(34,197,94,0.04))",
            border: "1px solid rgba(34,197,94,0.3)",
            borderRadius: 12, padding: 24, textAlign: "center", marginBottom: 16,
          }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>🎉</div>
            <h3 style={{ color: "#22c55e", margin: "0 0 8px" }}>You're all good!</h3>
            <p style={{ color: "#8b949e", fontSize: 14, margin: "0 0 20px" }}>
              Your contribution requirement for this month is already met.
            </p>
            <div style={{ marginBottom: 16, fontSize: 13, color: "#8b949e" }}>
              Pay in advance for the next cutoff <strong style={{ color: "#c9d1d9" }}>₱{formatCurrency(perCutoffAmount)}</strong>
            </div>
            <div style={{ display: "flex", gap: 12, justifyContent: "center" }}>
              <button className="btn btn-primary" onClick={onClose}>Skip</button>
              <button
                className="btn btn-outline"
                style={{ borderColor: "#22c55e", color: "#22c55e" }}
                onClick={() => setPayAdvance(true)}
              >
                Pay Advance
              </button>
            </div>
          </div>
        ) : (
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Quick Select {payAdvance ? `(next cutoff: ₱${formatCurrency(perCutoffAmount)})` : ''}</label>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              {quickAmounts.map((q, i) => (
                <button
                  key={i}
                  type="button"
                  className={`btn btn-sm ${Math.abs(Number(amount) - q) < 0.01 ? "btn-primary" : "btn-outline"}`}
                  onClick={() => setAmount(String(q))}
                  style={{ fontSize: 12, padding: "6px 12px" }}
                >
                  {i + 1 === 4 ? "Full" : `${25 * (i + 1)}%`} (₱{formatCurrency(q)})
                </button>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label>Amount (₱)</label>
            <input
              type="number"
              min="0"
              step="0.01"
              value={amount}
              onChange={e => setAmount(e.target.value)}
              required
            />
            <span className="form-hint">{payAdvance ? 'Next cutoff' : 'Min'}: ₱{formatCurrency(payAdvance ? perCutoffAmount : totalRequired)} • Max: ₱{formatCurrency(totalRequired * 5)}</span>
          </div>

          <div className="form-group">
            <button type="button" className="btn btn-outline btn-sm" onClick={() => setShowQR(!showQR)} style={{ width: "100%" }}>
              {showQR ? "Hide" : "Show"} QR Code — Scan to pay via GCash/PayMaya
            </button>
            {showQR && (
              <div style={{
                marginTop: 8, padding: 16, background: "#fff",
                borderRadius: 12, textAlign: "center",
              }}>
                {qrSettings.qrImageUrl ? (
                  <img
                    src={qrSettings.qrImageUrl}
                    alt="Payment QR"
                    style={{ width: 180, height: 180, margin: "0 auto 12px", borderRadius: 8, objectFit: "contain" }}
                  />
                ) : (
                  <div style={{
                    width: 160, height: 160, margin: "0 auto 12px",
                    background: "#f0f0f0", borderRadius: 8,
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontSize: 12, color: "#666",
                  }}>
                    QR Code
                  </div>
                )}
                <div style={{ fontSize: 12, color: "#333" }}>
                  {(qrSettings.qrAccountName || "No account name set")}
                  {qrSettings.qrAccountNumber ? <><br />{qrSettings.qrAccountNumber}</> : ""}
                </div>
              </div>
            )}
          </div>

          <div className="form-group">
            <label>Upload Receipt</label>
            {!receiptPreview ? (
              <div style={{ display: "flex", gap: 8 }}>
                <label className="btn btn-outline btn-sm" style={{ cursor: "pointer", flex: 1, textAlign: "center" }}>
                  📷 Take Photo
                  <input type="file" accept="image/*" capture="environment" onChange={handleFileChange} style={{ display: "none" }} />
                </label>
                <label className="btn btn-outline btn-sm" style={{ cursor: "pointer", flex: 1, textAlign: "center" }}>
                  🖼️ Gallery
                  <input type="file" accept="image/*" onChange={handleFileChange} style={{ display: "none" }} />
                </label>
              </div>
            ) : (
              <div style={{ border: "1px solid #21262d", borderRadius: 8, padding: 12 }}>
                <img src={receiptPreview} alt="Receipt" style={{ maxWidth: "100%", maxHeight: 200, borderRadius: 4, objectFit: "contain", marginBottom: 8 }} />
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <span style={{ fontSize: 12, color: "#8b949e" }}>{receiptFile?.name} ({(receiptFile?.size || 0) / 1024 > 1024 ? `${((receiptFile?.size || 0) / 1024 / 1024).toFixed(1)} MB` : `${((receiptFile?.size || 0) / 1024).toFixed(0)} KB`})</span>
                  <button type="button" className="btn-icon danger" onClick={removeReceipt}>
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                  </button>
                </div>
              </div>
            )}
          </div>

          <div className="modal-actions">
            <button type="button" className="btn btn-outline" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={submitting || !receiptFile}>
              {submitting ? "Submitting..." : "Submit for Approval"}
            </button>
          </div>
        </form>
        )}
      </div>
    </div>
  );
};

export default PaymentModal;
