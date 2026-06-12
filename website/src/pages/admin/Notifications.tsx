import React, { useEffect, useState, useMemo } from "react";
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

function getRelativeTime(d: Date): string {
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "Yesterday";
  if (days < 7) return `${days}d ago`;
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

const TYPE_META: Record<string, { icon: string; color: string; bg: string }> = {
  contribution: { icon: "\u{1F4B0}", color: "#22c55e", bg: "rgba(34,197,94,0.12)" },
  loan: { icon: "\u{1F3E6}", color: "#f59e0b", bg: "rgba(245,158,11,0.12)" },
  repayment: { icon: "\u{1F4B3}", color: "#3b82f6", bg: "rgba(59,130,246,0.12)" },
  payment: { icon: "\u{1F4B5}", color: "#8b5cf6", bg: "rgba(139,92,246,0.12)" },
  system: { icon: "\u2699\uFE0F", color: "#8b949e", bg: "rgba(139,148,158,0.12)" },
  approval: { icon: "\u2705", color: "#22c55e", bg: "rgba(34,197,94,0.12)" },
  warning: { icon: "\u26A0\uFE0F", color: "#f59e0b", bg: "rgba(245,158,11,0.12)" },
  reminder: { icon: "\u23F0", color: "#06b6d4", bg: "rgba(6,182,212,0.12)" },
};

function getTypeMeta(type: string) {
  return TYPE_META[type.toLowerCase()] || { icon: "\u{1F514}", color: "#8b949e", bg: "rgba(139,148,158,0.12)" };
}

const Notifications: React.FC = () => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "unread">("all");
  const [typeFilter, setTypeFilter] = useState("all");
  const [isMarking, setIsMarking] = useState(false);

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
    setIsMarking(true);
    try {
      const unread = notifications.filter(n => !n.read);
      for (const n of unread) {
        await updateDoc(doc(db, "notifications", n.id), { read: true });
      }
      setNotifications(prev => prev.map(n => ({ ...n, read: true })));
    } catch { /* ignore */ }
    finally { setIsMarking(false); }
  };

  const displayed = useMemo(() => {
    let result = filter === "unread" ? notifications.filter(n => !n.read) : [...notifications];
    if (typeFilter !== "all") result = result.filter(n => n.type.toLowerCase() === typeFilter);
    return result;
  }, [notifications, filter, typeFilter]);

  const unreadCount = notifications.filter(n => !n.read).length;

  const typeCounts = useMemo(() => {
    const counts: Record<string, number> = {};
    notifications.forEach(n => {
      const t = n.type.toLowerCase();
      counts[t] = (counts[t] || 0) + 1;
    });
    return counts;
  }, [notifications]);

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading notifications...</p></div>;

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Notifications</h1>
        <div style={{ display: "flex", gap: 8 }}>
          {unreadCount > 0 && (
            <button className="btn btn-outline btn-sm" onClick={markAllRead} disabled={isMarking}>
              {isMarking ? "Marking..." : `Mark All Read (${unreadCount})`}
            </button>
          )}
          <button className="btn btn-outline btn-sm" onClick={loadNotifications}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
            Refresh
          </button>
        </div>
      </div>

      <div className="notif-toolbar">
        <div className="notif-tabs">
          <button className={`notif-tab ${filter === "all" ? "active" : ""}`} onClick={() => setFilter("all")}>
            All
            <span className="notif-tab-count">{notifications.length}</span>
          </button>
          <button className={`notif-tab ${filter === "unread" ? "active" : ""}`} onClick={() => setFilter("unread")}>
            Unread
            {unreadCount > 0 && <span className="notif-tab-count">{unreadCount}</span>}
          </button>
        </div>
        <select className="search-input" value={typeFilter} onChange={e => setTypeFilter(e.target.value)} style={{ width: "auto", marginBottom: 0 }}>
          <option value="all">All Types</option>
          {Object.keys(TYPE_META).map(t => (
            <option key={t} value={t}>{t.charAt(0).toUpperCase() + t.slice(1)} ({typeCounts[t] || 0})</option>
          ))}
        </select>
      </div>

      <div className="notif-stats">
        <div className="notif-stat">
          <span className="notif-stat-value">{notifications.length}</span>
          <span className="notif-stat-label">Total</span>
        </div>
        <div className="notif-stat">
          <span className="notif-stat-value" style={{ color: "#22c55e" }}>{unreadCount}</span>
          <span className="notif-stat-label">Unread</span>
        </div>
        <div className="notif-stat">
          <span className="notif-stat-value" style={{ color: "#8b949e" }}>{notifications.length - unreadCount}</span>
          <span className="notif-stat-label">Read</span>
        </div>
      </div>

      {displayed.length === 0 ? (
        <p className="empty-text">No notifications found</p>
      ) : (
        <div className="notif-list">
          {displayed.map(n => {
            const meta = getTypeMeta(n.type);
            return (
              <div
                key={n.id}
                className={`notif-card ${!n.read ? "unread" : ""}`}
                onClick={() => !n.read && markRead(n.id)}
              >
                <div className="notif-card-icon" style={{ background: meta.bg }}>
                  {meta.icon}
                </div>
                <div className="notif-content">
                  <div className="notif-title">{n.title}</div>
                  <div className="notif-body">{n.body}</div>
                  <div className="notif-meta">
                    <span className="notif-time">{n.createdAt?.toDate?.() ? getRelativeTime(n.createdAt.toDate()) : ""}</span>
                    <span className="notif-type-badge" style={{ color: meta.color, background: meta.bg }}>{n.type}</span>
                  </div>
                </div>
                {!n.read && <div className="notif-unread-dot" />}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default Notifications;
