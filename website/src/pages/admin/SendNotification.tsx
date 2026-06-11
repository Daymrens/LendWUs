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
}

const TEMPLATES: Template[] = [
  {
    label: "Payment Reminder",
    icon: "💰",
    type: "payment",
    title: "Payment Reminder",
    body: "This is a reminder to make your pending payment at your earliest convenience to keep your account in good standing.",
  },
  {
    label: "Loan Approval",
    icon: "✅",
    type: "approval",
    title: "Loan Approved",
    body: "Your loan application has been approved. Please check your account for the updated details and disbursement schedule.",
  },
  {
    label: "Head Change",
    icon: "👥",
    type: "head_change",
    title: "Head Count Change",
    body: "Your head count has been updated. Please review the changes in your account and reach out if you have any questions.",
  },
  {
    label: "App Update",
    icon: "📱",
    type: "app_update",
    title: "New App Update Available",
    body: "A new version of the app is available. Please update to the latest version to enjoy new features and improvements.",
  },
  {
    label: "System Notice",
    icon: "ℹ️",
    type: "system",
    title: "System Maintenance Notice",
    body: "The system will be undergoing scheduled maintenance. Some features may be temporarily unavailable during this time.",
  },
  {
    label: "Meeting Reminder",
    icon: "📅",
    type: "reminder",
    title: "Meeting Reminder",
    body: "This is a reminder about the upcoming group meeting. Please make every effort to attend.",
  },
  {
    label: "Contribution Due",
    icon: "📊",
    type: "reminder",
    title: "Contribution Due Reminder",
    body: "Your monthly contribution is due soon. Please make your deposit on time to avoid any penalties or interruptions.",
  },
];

const SendNotification: React.FC = () => {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [recipient, setRecipient] = useState("all");
  const [type, setType] = useState("custom_notification");
  const [members, setMembers] = useState<Member[]>([]);
  const [selectedMemberId, setSelectedMemberId] = useState("");
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  useEffect(() => {
    getDocs(collection(db, "members")).then(snap => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as Member));
      setMembers(list);
    }).catch(() => {});
  }, []);

  const send = async () => {
    if (!title.trim() || !body.trim()) {
      setResult("Title and body are required");
      return;
    }
    setSending(true);
    setResult(null);

    try {
      let userIds: string[] = [];

      if (recipient === "member") {
        if (!selectedMemberId) {
          setResult("Select a member");
          setSending(false);
          return;
        }
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

      setResult(`Notification sent to ${userIds.length} user(s)`);
      setTitle("");
      setBody("");
      setSelectedMemberId("");
    } catch (err) {
      setResult(`Failed: ${err}`);
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Send Notification</h1>
      </div>

      <div className="notif-templates">
        <label className="notif-templates-label">Quick Templates</label>
        <div className="notif-templates-grid">
          {TEMPLATES.map((t, i) => (
            <button
              key={i}
              className="notif-template-btn"
              onClick={() => { setTitle(t.title); setBody(t.body); setType(t.type); }}
            >
              <span className="notif-template-icon">{t.icon}</span>
              <span className="notif-template-label">{t.label}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="send-notif-card">
        <div className="form-group">
          <label>Recipient</label>
          <select value={recipient} onChange={e => setRecipient(e.target.value)}>
            <option value="all">Everyone</option>
            <option value="admins">All Admins</option>
            <option value="members">All Members</option>
            <option value="member">Specific Member</option>
          </select>
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
            <option value="app_update">App Update</option>
            <option value="system">System</option>
          </select>
        </div>

        <div className="form-group">
          <label>Title</label>
          <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Notification title" />
        </div>

        <div className="form-group">
          <label>Message</label>
          <textarea className="send-notif-textarea" value={body} onChange={e => setBody(e.target.value)} placeholder="Notification body" rows={5} />
        </div>

        <button className="btn btn-primary btn-block" onClick={send} disabled={sending}>
          {sending ? "Sending..." : "Send Notification"}
        </button>

        {result && (
          <div className={`send-notif-result ${result.includes("sent") ? "success" : "error"}`}>
            {result}
          </div>
        )}
      </div>
    </div>
  );
};

export default SendNotification;
