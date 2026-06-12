import React, { useEffect, useState, useMemo, useCallback } from "react";
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
  deleteDoc,
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
  head_change: { icon: "\u{1F465}", color: "#8b5cf6", bg: "rgba(139,92,246,0.12)" },
};

function getTypeMeta(type: string) {
  return TYPE_META[type.toLowerCase()] || { icon: "\u{1F514}", color: "#8b949e", bg: "rgba(139,148,158,0.12)" };
}

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
  const [filter, setFilter] = useState<"all" | "unread">("all");
  const [typeFilter, setTypeFilter] = useState("all");
  const [confirmingClear, setConfirmingClear] = useState(false);

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

  const markAsRead = useCallback(async (id: string) => {
    try { await updateDoc(doc(db, "notifications", id), { read: true }); } catch { /* ignore */ }
  }, []);

  const markAllAsRead = useCallback(async () => {
    const unread = notifications.filter(n => !n.read);
    if (unread.length === 0) return;
    try {
      const batch = writeBatch(db);
      unread.forEach(n => batch.update(doc(db, "notifications", n.id), { read: true }));
      await batch.commit();
    } catch { /* ignore */ }
  }, [notifications]);

  const deleteNotification = useCallback(async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    try { await deleteDoc(doc(db, "notifications", id)); } catch { /* ignore */ }
  }, []);

  const clearRead = useCallback(async () => {
    const read = notifications.filter(n => n.read);
    if (read.length === 0) return;
    try {
      const batch = writeBatch(db);
      read.forEach(n => batch.delete(doc(db, "notifications", n.id)));
      await batch.commit();
    } catch { /* ignore */ }
  }, [notifications]);

  const clearAll = useCallback(async () => {
    if (notifications.length === 0) return;
    try {
      const batch = writeBatch(db);
      notifications.forEach(n => batch.delete(doc(db, "notifications", n.id)));
      await batch.commit();
    } catch { /* ignore */ }
    setConfirmingClear(false);
  }, [notifications]);

  const handleClick = useCallback((n: NotificationItem) => {
    if (!n.read) markAsRead(n.id);
    navigate(notificationRoute(n));
  }, [markAsRead, navigate]);

  const displayed = useMemo(() => {
    let result = filter === "unread" ? notifications.filter(n => !n.read) : [...notifications];
    if (typeFilter !== "all") result = result.filter(n => n.type.toLowerCase() === typeFilter);
    return result;
  }, [notifications, filter, typeFilter]);

  const unreadCount = notifications.filter(n => !n.read).length;
  const readCount = notifications.length - unreadCount;

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
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          {unreadCount > 0 && (
            <>
              <span className="chip active-chip">{unreadCount} unread</span>
              <button className="btn btn-outline btn-sm" onClick={markAllAsRead} style={{ borderColor: "#22c55e", color: "#22c55e" }}>
                Mark all read
              </button>
            </>
          )}
          {readCount > 0 && (
            <button className="btn btn-outline btn-sm" onClick={clearRead} style={{ borderColor: "#8b949e", color: "#8b949e" }}>
              Clear read
            </button>
          )}
          {notifications.length > 0 && (
            <button className="btn btn-outline btn-sm" onClick={() => setConfirmingClear(true)} style={{ borderColor: "#ef4444", color: "#ef4444" }}>
              Clear all
            </button>
          )}
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
          <span className="notif-stat-value" style={{ color: "#8b949e" }}>{readCount}</span>
          <span className="notif-stat-label">Read</span>
        </div>
      </div>

      {displayed.length === 0 ? (
        <div className="admin-loading">
          <div style={{ fontSize: 48, opacity: 0.3, marginBottom: 16 }}>
            {filter === "unread" ? "\u2705" : "\u{1F514}"}
          </div>
          <p className="empty-text">
            {filter === "unread" ? "All caught up!" : "No notifications found"}
          </p>
        </div>
      ) : (
        <div className="notif-list">
          {displayed.map(n => {
            const meta = getTypeMeta(n.type);
            return (
              <div
                key={n.id}
                className={`notif-card ${!n.read ? "unread" : ""}`}
                onClick={() => handleClick(n)}
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
                <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  {!n.read && <div className="notif-unread-dot" />}
                  <button
                    className="notif-delete-btn"
                    onClick={(e) => deleteNotification(n.id, e)}
                    title="Delete notification"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                    </svg>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {confirmingClear && (
        <div className="modal-overlay" onClick={() => setConfirmingClear(false)}>
          <div className="modal-box" onClick={e => e.stopPropagation()}>
            <h3>Clear all notifications?</h3>
            <p>This action cannot be undone. All {notifications.length} notifications will be permanently deleted.</p>
            <div className="modal-actions">
              <button className="btn btn-outline" onClick={() => setConfirmingClear(false)}>Cancel</button>
              <button className="btn btn-danger" onClick={clearAll}>Yes, clear all</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Notifications;
