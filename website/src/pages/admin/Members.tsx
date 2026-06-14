import React, { useEffect, useRef, useState } from "react";
import {
  collection,
  getDocs,
  addDoc,
  updateDoc,
  doc,
  query,
  where,
  Timestamp,
  writeBatch,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useNavigate } from "react-router-dom";
import { downloadCSV } from "../../utils/export";
import { backfillMissingMemberIds, generateNextMemberId } from "../../utils/memberId";

interface Member {
  id: string;
  memberId?: string;
  name: string;
  headsCount: number;
  amountPerHead: number;
  totalRequired: number;
  balance: number;
  joinedAt: Timestamp;
  active: boolean;
  linkedEmail?: string;
}

const Members: React.FC = () => {
  const [members, setMembers] = useState<Member[]>([]);
  const [filtered, setFiltered] = useState<Member[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState(0);
  const [showModal, setShowModal] = useState(false);
  const [editMember, setEditMember] = useState<Member | null>(null);
  const [paymentStatuses, setPaymentStatuses] = useState<Record<string, string>>({});
  const navigate = useNavigate();
  const tabs = ["All", "Active", "Inactive"];
  const backfillDone = useRef(false);

  useEffect(() => {
    loadMembers();
  }, []);

  useEffect(() => {
    if (!backfillDone.current) {
      backfillDone.current = true;
      backfillMissingMemberIds(db).catch(() => {});
    }
  }, []);

  useEffect(() => {
    let result = [...members];
    if (tab === 1) result = result.filter(m => m.active);
    if (tab === 2) result = result.filter(m => !m.active);
    if (search) {
      const q = search.toLowerCase();
      result = result.filter(m => m.name.toLowerCase().includes(q));
    }
    setFiltered(result);
  }, [members, tab, search]);

  const loadMembers = async () => {
    setLoading(true);
    setError("");
    try {
      const snap = await getDocs(collection(db, "members"));
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as Member));
      setMembers(list);

      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

      // Get contributions for this month to compute paid vs partial
      const contribSnap = await getDocs(collection(db, "contributions"));
      const thisMonthContribs = contribSnap.docs.filter(d => {
        const c = d.data();
        const dte = c.date?.toDate?.();
        return dte && dte >= monthStart && dte <= monthEnd;
      });
      const memberMonthTotal: Record<string, number> = {};
      thisMonthContribs.forEach(d => {
        const c = d.data() as Record<string, unknown>;
        const mid = c.memberId as string;
        memberMonthTotal[mid] = (memberMonthTotal[mid] || 0) + (Number(c.amount) || 0);
      });

      const statuses: Record<string, string> = {};
      list.forEach(m => {
        const totalRequired = m.totalRequired || 0;
        const paidThisMonth = memberMonthTotal[m.id] || 0;

        if (paidThisMonth >= totalRequired && totalRequired > 0) {
          statuses[m.id] = "paid";
        } else if (paidThisMonth > 0) {
          statuses[m.id] = "partial";
        } else {
          statuses[m.id] = "pending";
        }
      });
      setPaymentStatuses(statuses);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to load members";
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (data: Partial<Member>) => {
    try {
      if (editMember) {
        const ref = doc(db, "members", editMember.id);
        await updateDoc(ref, data);
      } else {
        const memberId = await generateNextMemberId(db);
        await addDoc(collection(db, "members"), {
          ...data,
          memberId,
          joinedAt: Timestamp.now(),
          active: true,
          balance: 0,
        });
      }
      setShowModal(false);
      setEditMember(null);
      loadMembers();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to save";
      alert(message);
    }
  };

  const handleToggleActive = async (m: Member) => {
    try {
      await updateDoc(doc(db, "members", m.id), { active: !m.active });
      loadMembers();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to update";
      alert(message);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm("Delete this member? This cannot be undone.")) return;
    try {
      const batch = writeBatch(db);
      batch.delete(doc(db, "members", id));

      const userSnap = await getDocs(query(collection(db, "users"), where("memberId", "==", id)));
      userSnap.docs.forEach(d => batch.delete(doc(db, "users", d.id)));

      const [contribSnap, loansSnap, payReqSnap, loanReqSnap, headSnap] = await Promise.all([
        getDocs(query(collection(db, "contributions"), where("memberId", "==", id))),
        getDocs(query(collection(db, "loans"), where("memberId", "==", id))),
        getDocs(query(collection(db, "payment_requests"), where("memberId", "==", id))),
        getDocs(query(collection(db, "loan_requests"), where("memberId", "==", id))),
        getDocs(query(collection(db, "head_change_requests"), where("memberId", "==", id))),
      ]);

      contribSnap.docs.forEach(d => batch.delete(doc(db, "contributions", d.id)));
      payReqSnap.docs.forEach(d => batch.delete(doc(db, "payment_requests", d.id)));
      loanReqSnap.docs.forEach(d => batch.delete(doc(db, "loan_requests", d.id)));
      headSnap.docs.forEach(d => batch.delete(doc(db, "head_change_requests", d.id)));

      const loanIds = loansSnap.docs.map(d => d.id);
      for (const loanId of loanIds) {
        const repaySnap = await getDocs(query(collection(db, "repayments"), where("loanId", "==", loanId)));
        repaySnap.docs.forEach(d => batch.delete(doc(db, "repayments", d.id)));
        batch.delete(doc(db, "loans", loanId));
      }

      await batch.commit();
      loadMembers();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to delete";
      alert(message);
    }
  };

  const exportStatement = async (m: Member) => {
    try {
      const [contSnap, loansSnap, paySnap] = await Promise.all([
        getDocs(query(collection(db, "contributions"), where("memberId", "==", m.id))),
        getDocs(query(collection(db, "loans"), where("memberId", "==", m.id))),
        getDocs(query(collection(db, "payment_requests"), where("memberId", "==", m.id))),
      ]);
      const rows: Record<string, unknown>[] = [];
      contSnap.docs.forEach(d => {
        const c = d.data(); rows.push({ Date: c.date?.toDate?.()?.toLocaleDateString() || "", Type: "Contribution", Amount: c.amount, Status: c.status });
      });
      loansSnap.docs.forEach(d => {
        const l = d.data(); rows.push({ Date: l.issuedDate?.toDate?.()?.toLocaleDateString() || "", Type: "Loan", Amount: l.principal, Status: l.isFullyRepaid ? "Repaid" : "Active" });
      });
      paySnap.docs.forEach(d => {
        const p = d.data(); rows.push({ Date: p.createdAt?.toDate?.()?.toLocaleDateString() || "", Type: "Payment", Amount: p.amount, Status: p.status });
      });
      rows.sort((a, b) => String(a.Date).localeCompare(String(b.Date)));
      downloadCSV(rows, `statement_${m.name.replace(/\s+/g, "_")}`);
    } catch { alert("Failed to export statement"); }
  };

  const statusChip = (status: string) => {
    if (status === "paid") return <span className="chip active-chip">PAID</span>;
    if (status === "overdue") return <span className="chip" style={{ background: "rgba(239,68,68,0.15)", color: "#ef4444" }}>OVERDUE</span>;
    if (status === "partial") return <span className="chip" style={{ background: "rgba(234,179,8,0.15)", color: "#eab308" }}>PARTIAL</span>;
    return <span className="chip badge-orange">PENDING</span>;
  };

  const totalContributions = members.reduce((s, m) => s + (m.totalRequired ?? 0), 0);
  const activeCount = members.filter(m => m.active).length;

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading members...</p></div>;
  if (error) return <div className="admin-error"><p>Error: {error}</p><button className="btn btn-primary" onClick={loadMembers}>Retry</button></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Members</h1>
        <button className="btn btn-primary btn-sm" onClick={() => { setEditMember(null); setShowModal(true); }}>
          + Add Member
        </button>
      </div>

      <div className="members-toolbar">
        <input
          type="text"
          placeholder="Search members..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="search-input"
        />
        <div className="tabs">
          {tabs.map((t, i) => (
            <button key={t} className={`tab ${i === tab ? "active" : ""}`} onClick={() => setTab(i)}>
              {t}
            </button>
          ))}
        </div>
        <div className="member-chips">
          <span className="chip active-chip">{activeCount} Active</span>
          <span className="chip inactive-chip">{members.length - activeCount} Inactive</span>
          <span className="chip total-chip">Total: ₱{totalContributions.toLocaleString()}</span>
        </div>
      </div>

      {filtered.length === 0 ? (
        <p className="empty-text">{members.length === 0 ? "No members yet" : "No matches"}</p>
      ) : (
        <div className="members-list">
          {filtered.map(m => (
            <div key={m.id} className={`member-card ${!m.active ? "inactive" : ""}`}>
              <div className="member-info">
                <div className="member-name">
                  <span className="member-name-link" onClick={() => navigate(`/admin/members/${m.id}`)}>{m.name}</span>
                  {m.memberId && <span className="member-id-badge">{m.memberId}</span>}
                  {statusChip(paymentStatuses[m.id] || "pending")}
                </div>
                <div className="member-details">
                  {m.linkedEmail && <span>{m.linkedEmail}</span>}
                  <span>{m.headsCount} head{m.headsCount > 1 ? "s" : ""}</span>
                  {!m.active && <span className="badge badge-inactive">Inactive</span>}
                </div>
                <div className="member-details">
                  <span>₱{(m.amountPerHead ?? 0).toLocaleString()}/head</span>
                  <span>Required: ₱{(m.totalRequired ?? 0).toLocaleString()}</span>
                  <span>Balance: ₱{(m.balance ?? 0).toLocaleString()}</span>
                </div>
              </div>
              <div className="member-actions">
                <button className="btn-icon" title="Export Statement" onClick={() => exportStatement(m)}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                </button>
                <button className="btn-icon" title="Edit" onClick={() => { setEditMember(m); setShowModal(true); }}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                </button>
                <button className="btn-icon" title={m.active ? "Deactivate" : "Activate"} onClick={() => handleToggleActive(m)}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    {m.active
                      ? <><circle cx="12" cy="12" r="10"/><path d="M4.93 4.93l14.14 14.14"/></>
                      : <><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></>
                    }
                  </svg>
                </button>
                <button className="btn-icon danger" title="Delete" onClick={() => handleDelete(m.id)}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {showModal && (
        <MemberModal
          member={editMember}
          onSave={handleSave}
          onClose={() => { setShowModal(false); setEditMember(null); }}
        />
      )}
    </div>
  );
};

interface MemberModalProps {
  member: Member | null;
  onSave: (data: Partial<Member>) => Promise<void>;
  onClose: () => void;
}

const MemberModal: React.FC<MemberModalProps> = ({ member, onSave, onClose }) => {
  const [name, setName] = useState(member?.name || "");
  const [heads, setHeads] = useState(String(member?.headsCount || 1));
  const [amountPerHead, setAmountPerHead] = useState(String(member?.amountPerHead || 0));
  const [email, setEmail] = useState(member?.linkedEmail || "");
  const [totalRequired, setTotalRequired] = useState(String(member?.totalRequired || 0));
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const h = Number(heads) || 0;
    const a = Number(amountPerHead) || 0;
    setTotalRequired(String(h * a));
  }, [heads, amountPerHead]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;
    setSubmitting(true);
    try {
      await onSave({
        name: name.trim(),
        headsCount: Number(heads),
        amountPerHead: Number(amountPerHead),
        totalRequired: Number(totalRequired),
        linkedEmail: email.trim() || undefined,
      });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>{member ? "Edit Member" : "Add Member"}</h2>
          <button className="btn-icon" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Name</label>
            <input type="text" value={name} onChange={e => setName(e.target.value)} required />
          </div>
          <div className="form-row">
            <div className="form-group">
              <label>Heads</label>
              <input type="number" min="1" value={heads} onChange={e => setHeads(e.target.value)} required />
            </div>
            <div className="form-group">
              <label>Amount per Head</label>
              <input type="number" min="0" step="0.01" value={amountPerHead} onChange={e => setAmountPerHead(e.target.value)} required />
            </div>
          </div>
          <div className="form-group">
            <label>Total Required (auto-calculated)</label>
            <input type="text" value={`₱${(Number(totalRequired) || 0).toLocaleString()}`} disabled />
          </div>
          <div className="form-group">
            <label>Linked Email (optional)</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} />
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-outline" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? "Saving..." : member ? "Update" : "Add Member"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default Members;
