import { useEffect, useRef, useState, useCallback } from "react";
import { collection, query, where, orderBy, onSnapshot } from "firebase/firestore";
import { db } from "../firebase";

export type NotificationPermissionState = "prompt" | "granted" | "denied" | "loading";

export function useWebNotifications(userId: string | null | undefined) {
  const [permState, setPermState] = useState<NotificationPermissionState>("loading");
  const [dismissed, setDismissed] = useState(false);
  const seenRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    if (!("Notification" in window)) {
      setPermState("denied");
      return;
    }
    const raw = Notification.permission;
    setPermState(raw === "default" ? "prompt" : raw as NotificationPermissionState);
  }, []);

  const requestPermission = useCallback(async () => {
    if (!("Notification" in window)) return;
    const result = await Notification.requestPermission();
    setPermState(result === "default" ? "prompt" : result as NotificationPermissionState);
  }, []);

  const dismiss = useCallback(() => setDismissed(true), []);

  useEffect(() => {
    if (permState !== "granted" || !userId) return;

    const q = query(
      collection(db, "notifications"),
      where("userId", "==", userId),
      where("read", "==", false),
      orderBy("createdAt", "desc"),
    );

    const unsub = onSnapshot(q, (snap) => {
      for (const change of snap.docChanges()) {
        if (change.type !== "added") continue;
        const id = change.doc.id;
        const currentSeen = seenRef.current;
        if (currentSeen.has(id)) continue;
        currentSeen.add(id);

        const data = change.doc.data();
        const title = data.title || "LendWUs";
        const body = data.body || "";
        if ("Notification" in window && Notification.permission === "granted") {
          new Notification(title, { body, icon: "/logo192.png" });
        }
      }
    });

    const seenSet = seenRef.current;
    return () => {
      unsub();
      seenSet.clear();
    };
  }, [permState, userId]);

  const showPrompt = permState === "prompt" && !dismissed;

  return { showPrompt, permState, requestPermission, dismiss };
}
