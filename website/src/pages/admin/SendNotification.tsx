import React, { useEffect, useState } from "react";
import { collection, getDocs, doc, setDoc, Timestamp } from "firebase/firestore";
import { db } from "../../firebase";

interface Member {
  id: string;
  name: string;
}

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
