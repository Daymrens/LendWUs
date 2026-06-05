import React, { useEffect, useState } from "react";
import { collection, getDocs, updateDoc, doc, query, orderBy, Timestamp } from "firebase/firestore";
import { db } from "../../firebase";
interface Notification {
  id: string;
  userId: string;
  title: string;
  body: string;
  type: string;
  read: boolean;
  createdAt: Timestamp;
}

const Notifications: React.FC = () => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "unread">("all");

  useEffect(() => {
    loadNotifications();
  }, []);

  const loadNotifications = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, "notifications"), orderBy("createdAt", "desc"));
      const snap = await getDocs(q);
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() } as Notification));
      setNotifications(list);
    } catch { /* ignore */ }
    finally { setLoading(false); }
  };

  const markRead = async (id: string) => {
    try {
      await updateDoc(doc(db, "notifications", id), { read: true });
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));
    } catch { /* ignore */ }
  };

  const markAllRead = async () => {
    try {
      for (const n of notifications.filter(n => !n.read)) {
        await updateDoc(doc(db, "notifications", n.id), { read: true });
      }
      setNotifications(prev => prev.map(n => ({ ...n, read: true })));
    } catch { /* ignore */ }
  };

  const displayed = filter === "unread" ? notifications.filter(n => !n.read) : notifications;

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading notifications...</p></div>;

  const unreadCount = notifications.filter(n => !n.read).length;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Notifications</h1>
        <div style={{ display: "flex", gap: 8 }}>
          {unreadCount > 0 && <button className="btn btn-outline btn-sm" onClick={markAllRead}>Mark All Read</button>}
          <button className="btn btn-outline btn-sm" onClick={loadNotifications}>Refresh</button>
        </div>
      </div>

      <div className="tabs" style={{ marginBottom: 16 }}>
        <button className={`tab ${filter==="all"?"active":""}`} onClick={()=>setFilter("all")}>All ({notifications.length})</button>
        <button className={`tab ${filter==="unread"?"active":""}`} onClick={()=>setFilter("unread")}>Unread ({unreadCount})</button>
      </div>

      {displayed.length === 0 ? (
        <p className="empty-text">No notifications</p>
      ) : (
        <div className="notif-list">
          {displayed.map(n => (
            <div key={n.id} className={`notif-card ${!n.read ? "unread" : ""}`} onClick={() => !n.read && markRead(n.id)}>
              <div className="notif-dot" />
              <div className="notif-content">
                <div className="notif-title">{n.title}</div>
                <div className="notif-body">{n.body}</div>
                <div className="notif-time">{n.createdAt?.toDate?.()?.toLocaleString() || ""}</div>
              </div>
              {!n.read && <div className="notif-unread-dot" />}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default Notifications;
