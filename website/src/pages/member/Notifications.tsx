import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  updateDoc,
  doc,
  writeBatch,
  Timestamp,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";

interface NotificationItem {
  id: string;
  userId: string;
  title: string;
  body: string;
  type: string;
  read: boolean;
  createdAt: Timestamp;
  data?: Record<string, unknown>;
}

const typeIcons: Record<string, string> = {
  payment: "💰",
  loan: "🏦",
  approval: "✅",
  head_change: "👥",
  reminder: "⏰",
  system: "ℹ️",
};

function notificationRoute(n: NotificationItem): string {
  const route = n.data?.route as string | undefined;
  if (route) return route;
  const t = n.type;
  if (t === "payment" || t === "loan" || t === "head_change") return "/member/requests";
  if (t === "approval") return "/member/requests";
  return "/member/dashboard";
}

const Notifications: React.FC = () => {
  const { user } = useMemberAuth();
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user?.uid) return;
    const unsub = onSnapshot(
      query(collection(db, "notifications"), where("userId", "==", user.uid), orderBy("createdAt", "desc")),
      (snap) => {
        setNotifications(snap.docs.map(d => ({ id: d.id, ...d.data() } as NotificationItem)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return unsub;
  }, [user?.uid]);

  const markAsRead = async (id: string) => {
    try { await updateDoc(doc(db, "notifications", id), { read: true }); } catch { /* ignore */ }
  };

  const markAllAsRead = async () => {
    const unread = notifications.filter(n => !n.read);
    if (unread.length === 0) return;
    try {
      const batch = writeBatch(db);
      unread.forEach(n => batch.update(doc(db, "notifications", n.id), { read: true }));
      await batch.commit();
    } catch { /* ignore */ }
  };

  const handleClick = (n: NotificationItem) => {
    if (!n.read) markAsRead(n.id);
    navigate(notificationRoute(n));
  };

  const formatTime = (ts: Timestamp) => {
    if (!ts?.toDate) return "";
    const d = ts.toDate();
    const diff = Math.floor((Date.now() - d.getTime()) / (1000 * 60));
    if (diff < 1) return "Just now";
    if (diff < 60) return `${diff}m ago`;
    const hours = Math.floor(diff / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days < 7) return `${days}d ago`;
    return d.toLocaleDateString();
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading notifications...</p></div>;

  const unreadCount = notifications.filter(n => !n.read).length;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Notifications</h1>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          {unreadCount > 0 && (
            <>
              <span className="chip active-chip">{unreadCount} unread</span>
              <button className="btn btn-outline btn-sm" onClick={markAllAsRead} style={{ borderColor: "#22c55e", color: "#22c55e" }}>
                Mark all read
              </button>
            </>
          )}
        </div>
      </div>

      {notifications.length === 0 ? (
        <div className="admin-loading">
          <div style={{ fontSize: 48, opacity: 0.3, marginBottom: 16 }}>🔔</div>
          <p className="empty-text">No notifications yet</p>
        </div>
      ) : (
        <div className="notif-list">
          {notifications.map(n => (
            <div
              key={n.id}
              className={`notif-card ${!n.read ? "unread" : ""}`}
              onClick={() => handleClick(n)}
              style={{ cursor: "pointer" }}
            >
              <span style={{ fontSize: 20 }}>{typeIcons[n.type] || "ℹ️"}</span>
              <div className="notif-content">
                <div className="notif-title">{n.title}</div>
                <div className="notif-body">{n.body}</div>
                <div className="notif-time">{formatTime(n.createdAt)}</div>
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
