import React, { useEffect, useState } from "react";
import { collection, getDocs, doc, setDoc, Timestamp } from "firebase/firestore";
import { db } from "../../firebase";

interface Member {
  id: string;
  name: string;
}

interface Template {
  label: string;
  icon: string;
  type: string;
  title: string;
  body: string;
  category: string;
  recipient?: string;
}

const TEMPLATES: Template[] = [
  { label: "Contribution Due", icon: "\u{1F4B0}", type: "payment", category: "reminders", recipient: "members",
    title: "Contribution Due",
    body: "This is a friendly reminder that your monthly contribution is now due. Please submit your payment at your earliest convenience." },
  { label: "Overdue Alert", icon: "\u26A0\uFE0F", type: "payment", category: "reminders", recipient: "members",
    title: "Payment Overdue",
    body: "Your contribution for this month is now overdue. Kindly remit immediately to avoid any lapse in your standing." },
  { label: "Loan Due Reminder", icon: "\u{1F3E6}", type: "loan", category: "reminders", recipient: "members",
    title: "Loan Repayment Due",
    body: "Your loan repayment is due soon. Please settle your payment to keep your account in good standing." },
  { label: "Meeting Notice", icon: "\u{1F4C5}", type: "custom_notification", category: "reminders", recipient: "all",
    title: "Upcoming Fund Meeting",
    body: "We will be having our fund meeting on [DATE]. Your attendance is kindly requested." },
  { label: "Loan Approved", icon: "\u2705", type: "approval", category: "updates", recipient: "member",
    title: "Loan Approved",
    body: "Congratulations! Your loan has been approved. The amount has been disbursed to your account." },
  { label: "Fund Update", icon: "\u{1F4C8}", type: "custom_notification", category: "updates", recipient: "all",
    title: "Fund Performance Update",
    body: "Our fund balance is performing well. Thank you for your continued contributions and support." },
  { label: "Head Change Approved", icon: "\u{1F465}", type: "head_change", category: "updates", recipient: "member",
    title: "Head Count Updated",
    body: "Your head count change request has been approved. Please check your account for the updated details." },
  { label: "Thank You", icon: "\u{1F389}", type: "payment", category: "updates", recipient: "members",
    title: "Thank You!",
    body: "Thank you for your timely contribution! Your consistent support keeps our fund strong." },
  { label: "General Notice", icon: "\u2139\uFE0F", type: "custom_notification", category: "notices", recipient: "all",
    title: "Important Announcement",
    body: "Please be informed of the following update regarding our fund: [DETAILS]." },
  { label: "System Maintenance", icon: "\u{1F6A7}", type: "system", category: "notices", recipient: "all",
    title: "System Maintenance Notice",
    body: "The system will be undergoing scheduled maintenance. Some features may be unavailable." },
  { label: "App Update", icon: "\u{1F4F1}", type: "app_update", category: "notices", recipient: "all",
    title: "New App Update Available",
    body: "A new version of the app is available. Please update to enjoy new features and improvements." },
];

const CATEGORIES = [
  { key: "reminders", label: "Reminders" },
  { key: "updates", label: "Updates" },
  { key: "notices", label: "Notices" },
];

const SendNotification: React.FC = () => {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [recipient, setRecipient] = useState("all");
  const [type, setType] = useState("custom_notification");
  const [members, setMembers] = useState<Member[]>([]);
  const [selectedMemberId, setSelectedMemberId] = useState("");
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; msg: string } | null>(null);
  const [activeCategory, setActiveCategory] = useState("reminders");

  useEffect(() => {
    getDocs(collection(db, "members")).then(snap => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as Member));
      setMembers(list);
    }).catch(() => {});
  }, []);

  const [estimatedCount, setEstimatedCount] = useState<number | null>(null);

  useEffect(() => {
    if (recipient === "member") {
      setEstimatedCount(selectedMemberId ? 1 : 0);
      return;
    }
    getDocs(collection(db, "users")).then(snap => {
      const all = snap.docs.map(d => ({ id: d.id, role: d.data().role }));
      if (recipient === "admins") setEstimatedCount(all.filter(u => u.role === "admin").length);
      else if (recipient === "members") setEstimatedCount(all.filter(u => u.role === "member").length);
      else setEstimatedCount(all.length);
    }).catch(() => setEstimatedCount(null));
  }, [recipient, selectedMemberId]);

  const send = async () => {
    if (!title.trim() || !body.trim()) {
      setResult({ ok: false, msg: "Title and body are required" });
      return;
    }
    if (estimatedCount !== null && estimatedCount === 0) {
      setResult({ ok: false, msg: "No recipients match your selection" });
      return;
    }
    setSending(true);
    setResult(null);

    try {
      let userIds: string[] = [];

      if (recipient === "member") {
        const userSnap = await getDocs(collection(db, "users"));
        const userDoc = userSnap.docs.find(d => d.data().memberId === selectedMemberId);
        if (userDoc) userIds = [userDoc.id];
      } else {
        const userSnap = await getDocs(collection(db, "users"));
        const allUsers = userSnap.docs.map(d => ({ id: d.id, role: d.data().role }));
        if (recipient === "admins") userIds = allUsers.filter(u => u.role === "admin").map(u => u.id);
        else if (recipient === "members") userIds = allUsers.filter(u => u.role === "member").map(u => u.id);
        else userIds = allUsers.map(u => u.id);
      }

      const now = Timestamp.now();
      for (const uid of userIds) {
        const notifRef = doc(collection(db, "notifications"));
        await setDoc(notifRef, {
          userId: uid,
          title: title.trim(),
          body: body.trim(),
          type,
          read: false,
          createdAt: now,
        });
      }

      setResult({ ok: true, msg: `Notification sent to ${userIds.length} user${userIds.length !== 1 ? "s" : ""}` });
      setTitle("");
      setBody("");
      setSelectedMemberId("");
    } catch (err) {
      setResult({ ok: false, msg: `Failed: ${err}` });
    } finally {
      setSending(false);
    }
  };

  const charsLeft = 500 - body.length;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Send Notification</h1>
      </div>

      <div className="send-notif-layout">
        <div className="send-notif-form">
          <div className="send-notif-card">
            <div className="send-notif-card-header">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 2L11 13"/><path d="M22 2l-7 20-4-9-9-4 20-7z"/></svg>
              Compose Message
            </div>

            <div className="form-group">
              <label>Recipient</label>
              <div className="recipient-row">
                <select value={recipient} onChange={e => setRecipient(e.target.value)}>
                  <option value="all">Everyone</option>
                  <option value="admins">All Admins</option>
                  <option value="members">All Members</option>
                  <option value="member">Specific Member</option>
                </select>
                {estimatedCount !== null && (
                  <span className="recipient-estimate">
                    ~{estimatedCount} user{estimatedCount !== 1 ? "s" : ""}
                  </span>
                )}
              </div>
            </div>

            {recipient === "member" && (
              <div className="form-group">
                <label>Select Member</label>
                <select value={selectedMemberId} onChange={e => setSelectedMemberId(e.target.value)}>
                  <option value="">-- Select --</option>
                  {members.map(m => (
                    <option key={m.id} value={m.id}>{m.name}</option>
                  ))}
                </select>
              </div>
            )}

            <div className="form-group">
              <label>Notification Type</label>
              <select value={type} onChange={e => setType(e.target.value)}>
                <option value="custom_notification">Custom</option>
                <option value="payment">Payment</option>
                <option value="approval">Approval</option>
                <option value="reminder">Reminder</option>
                <option value="app_update">App Update</option>
                <option value="system">System</option>
              </select>
            </div>

            <div className="form-group">
              <label>Title</label>
              <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Notification title" />
            </div>

            <div className="form-group">
              <label>
                Message
                <span className={`char-counter ${charsLeft < 50 ? "char-counter-low" : ""}`}>
                  {charsLeft}
                </span>
              </label>
              <textarea className="send-notif-textarea" value={body} onChange={e => setBody(e.target.value.slice(0, 500))} placeholder="Notification body" rows={5} />
            </div>

            <button className="btn btn-primary btn-block" onClick={send} disabled={sending || !title.trim() || !body.trim()}>
              {sending ? (
                <><span className="btn-spinner" /> Sending...</>
              ) : (
                <><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 2L11 13"/><path d="M22 2l-7 20-4-9-9-4 20-7z"/></svg> Send Notification</>
              )}
            </button>

            {result && (
              <div className={`send-notif-result ${result.ok ? "success" : "error"}`}>
                {result.ok ? "\u2705" : "\u26A0\uFE0F"} {result.msg}
              </div>
            )}
          </div>
        </div>

        <div className="send-notif-side">
          <div className="notif-templates">
            <div className="notif-templates-label">Quick Templates</div>
            <div className="notif-template-categories">
              {CATEGORIES.map(cat => (
                <button
                  key={cat.key}
                  className={`notif-template-cat ${activeCategory === cat.key ? "active" : ""}`}
                  onClick={() => setActiveCategory(cat.key)}
                >{cat.label}</button>
              ))}
            </div>
            <div className="notif-templates-grid">
              {TEMPLATES.filter(t => t.category === activeCategory).map((t, i) => (
                <button
                  key={i}
                  className="notif-template-btn"
                  onClick={() => { setTitle(t.title); setBody(t.body); setType(t.type); if (t.recipient) setRecipient(t.recipient); }}
                >
                  <span className="notif-template-icon">{t.icon}</span>
                  <span className="notif-template-label">{t.label}</span>
                </button>
              ))}
            </div>
          </div>

          {(title || body) && (
            <div className="notif-preview-card">
              <div className="notif-preview-header">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
                Preview
              </div>
              <div className="notif-preview-card-body">
                <div className="notif-preview-icon">
                  {type === "payment" ? "\u{1F4B0}" : type === "loan" ? "\u{1F3E6}" : type === "approval" ? "\u2705" : type === "reminder" ? "\u23F0" : type === "all_paid" ? "\u{1F389}" : type === "system" ? "\u2139\uFE0F" : "\u{1F514}"}
                </div>
                <div className="notif-preview-content">
                  <div className="notif-preview-title">{title || "Notification Title"}</div>
                  <div className="notif-preview-body">{body || "Notification message will appear here..."}</div>
                </div>
                <div className="notif-preview-dot" />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default SendNotification;
