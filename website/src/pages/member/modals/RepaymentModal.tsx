import React, { useState, useEffect } from "react";
import {
  collection,
  addDoc,
  Timestamp,
  doc,
  getDoc,
} from "firebase/firestore";
import { db } from "../../../firebase";
import { compressImage } from "../../../utils/image";

interface RepaymentModalProps {
  memberDocId: string;
  loanId: string;
  principal: number;
  interestRate: number;
  remainingBalance: number;
  onClose: () => void;
}

interface QRSettings {
  qrAccountName: string;
  qrAccountNumber: string;
  qrImageUrl: string;
}

const formatCurrency = (n: number) =>
  n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const RepaymentModal: React.FC<RepaymentModalProps> = ({
  memberDocId, loanId, principal, interestRate, remainingBalance, onClose,
}) => {
  const [amount, setAmount] = useState(String(remainingBalance));
  const [receiptFile, setReceiptFile] = useState<File | null>(null);
  const [receiptPreview, setReceiptPreview] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
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
      await addDoc(collection(db, "payment_requests"), {
        memberId: memberDocId,
        loanId: loanId,
        amount: amt,
        type: "loan",
        status: "pending",
        requestDate: Timestamp.now(),
        month: d.getMonth() + 1,
        year: d.getFullYear(),
        notes: "",
        receiptPath: receiptPreview,
        receiptUrl: receiptPreview,
        receiptFilename: receiptFile.name,
      });
      onClose();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Failed to submit");
    } finally { setSubmitting(false); }
  };

  const totalDue = principal + (principal * interestRate);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 520 }}>
        <div className="modal-header">
          <h2>Repay Loan</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>

        {/* Remaining Balance Card */}
        <div style={{
          background: "linear-gradient(135deg, rgba(245,158,11,0.15), rgba(245,158,11,0.05))",
          border: "1px solid rgba(245,158,11,0.3)",
          borderRadius: 12, padding: 16, marginBottom: 16,
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2">
              <rect x="2" y="5" width="20" height="14" rx="2"/><line x1="12" y1="12" x2="12" y2="12"/>
            </svg>
            <span style={{ color: "#f59e0b", fontWeight: 600, fontSize: 14 }}>Remaining Balance</span>
          </div>
          <div style={{ fontSize: 28, fontWeight: 800, color: "#f59e0b" }}>
            ₱{formatCurrency(remainingBalance)}
          </div>
          <div style={{ marginTop: 4, fontSize: 12, color: "#8b949e" }}>
            Total due: ₱{formatCurrency(totalDue)} • Principal: ₱{formatCurrency(principal)}
          </div>
        </div>

        <form onSubmit={handleSubmit}>
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
            <span className="form-hint">Remaining balance: ₱{formatCurrency(remainingBalance)}</span>
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
      </div>
    </div>
  );
};

export default RepaymentModal;