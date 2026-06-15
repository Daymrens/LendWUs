import React, { createContext, useContext, useEffect, useState, useRef, useCallback } from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  signOut,
  User as FirebaseUser,
} from "firebase/auth";
import { doc, getDoc, getDocs, setDoc, runTransaction, collection, query, where, limit, onSnapshot, serverTimestamp } from "firebase/firestore";
import { auth, db } from "../firebase";
import { generateNextMemberId } from "../utils/memberId";

export interface AppUser {
  uid: string;
  email: string;
  role: "admin" | "member";
  username?: string;
  memberId?: string; // This is the doc ID
  customMemberId?: string; // This is the LWS format ID
  photoUrl?: string;
  isTreasurer?: boolean;
}

interface AuthResult {
  success: boolean;
  error?: string;
  role?: "admin" | "member";
}

interface AuthContextType {
  user: AppUser | null;
  firebaseUser: FirebaseUser | null;
  loading: boolean;
  error: string | null;
  isRecognized: boolean;
  login: (email: string, password: string) => Promise<AuthResult>;
  signInWithGoogle: () => Promise<AuthResult>;
  joinWithGroupCode: (code: string) => Promise<AuthResult>;
  logout: () => Promise<void>;
  clearError: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

async function checkAdminEmail(email: string): Promise<boolean> {
  try {
    const settingsDoc = await getDoc(doc(db, "app_settings", "fund_settings"));
    if (settingsDoc.exists()) {
      const adminEmails = settingsDoc.data()?.adminEmails || [];
      return adminEmails.includes(email);
    }
  } catch (err) {
    console.error("[Auth] checkAdminEmail error:", err);
  }
  return false;
}

async function findMemberByLinkedEmail(email: string): Promise<{ id: string; memberId: string; isActive: boolean } | null> {
  try {
    const snapshot = await getDocs(query(collection(db, "members"), where("linkedEmail", "==", email), limit(1)));
    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      const data = doc.data();
      return { id: doc.id, memberId: data.memberId || "", isActive: (data.active ?? data.isActive) !== false };
    }
  } catch (err) {
    console.error("[Auth] findMemberByLinkedEmail error:", err);
  }
  return null;
}

async function checkTreasurerEmail(email: string): Promise<boolean> {
  try {
    const settingsDoc = await getDoc(doc(db, "app_settings", "fund_settings"));
    if (settingsDoc.exists()) {
      const treasurerEmails = settingsDoc.data()?.treasurerEmails || [];
      return treasurerEmails.includes(email);
    }
  } catch (err) {
    console.error("[Auth] checkTreasurerEmail error:", err);
  }
  return false;
}

async function resolveUser(fbUser: FirebaseUser): Promise<{
  appUser: AppUser | null;
  recognized: boolean;
  error?: string;
}> {
  const userDoc = await getDoc(doc(db, "users", fbUser.uid));
  const email = fbUser.email || "";

  if (!userDoc.exists()) {
    const isAdmin = await checkAdminEmail(email);
    if (isAdmin) {
      await setDoc(doc(db, "users", fbUser.uid), {
        username: fbUser.displayName || email.split("@")[0],
        email,
        role: "admin",
        photoUrl: fbUser.photoURL || "",
        createdAt: new Date().toISOString(),
      });
      return {
        appUser: { uid: fbUser.uid, email, role: "admin", username: fbUser.displayName || email.split("@")[0], photoUrl: fbUser.photoURL || undefined },
        recognized: true,
      };
    }

    const isTreasurerEmail = await checkTreasurerEmail(email);

    // Fallback: try to find a member with matching linkedEmail (same logic as Flutter app)
    const linkedMember = await findMemberByLinkedEmail(email);
    if (linkedMember && linkedMember.isActive) {
      await setDoc(doc(db, "users", fbUser.uid), {
        username: fbUser.displayName || email.split("@")[0],
        email,
        role: "member",
        memberId: linkedMember.id,
        photoUrl: fbUser.photoURL || "",
        createdAt: new Date().toISOString(),
      });
      return {
        appUser: {
          uid: fbUser.uid,
          email,
          role: "member",
          username: fbUser.displayName || email.split("@")[0],
          memberId: linkedMember.id,
          customMemberId: linkedMember.memberId,
          photoUrl: fbUser.photoURL || undefined,
          isTreasurer: isTreasurerEmail,
        },
        recognized: true,
      };
    }

    if (isTreasurerEmail) {
      await setDoc(doc(db, "users", fbUser.uid), {
        username: fbUser.displayName || email.split("@")[0],
        email,
        role: "member",
        isTreasurer: true,
        photoUrl: fbUser.photoURL || "",
        createdAt: new Date().toISOString(),
      });
      return {
        appUser: { uid: fbUser.uid, email, role: "member", username: fbUser.displayName || email.split("@")[0], photoUrl: fbUser.photoURL || undefined, isTreasurer: true },
        recognized: true,
      };
    }

    return {
      appUser: { uid: fbUser.uid, email, role: "member", username: fbUser.displayName || email.split("@")[0], photoUrl: fbUser.photoURL || undefined },
      recognized: false,
    };
  }

  const data = userDoc.data();
  const role = data.role as "admin" | "member";

  // Treasurer flag upgrade: if user exists and email is now in treasurerEmails
  if (role === "member" && !data.isTreasurer) {
    const isTreasurerEmail = await checkTreasurerEmail(email);
    if (isTreasurerEmail) {
      await setDoc(doc(db, "users", fbUser.uid), { isTreasurer: true }, { merge: true });
      return {
        appUser: { uid: fbUser.uid, email, role: "member", username: data.username, photoUrl: data.photoUrl, isTreasurer: true, memberId: data.memberId },
        recognized: true,
      };
    }
  }

  if (role === "admin") {
    return {
      appUser: { uid: fbUser.uid, email: fbUser.email || data.email || "", role: "admin", username: data.username, photoUrl: data.photoUrl },
      recognized: true,
    };
  }

  if (role !== "member") {
    return { appUser: null, recognized: false, error: "Unknown account role." };
  }

  // Try to repair broken memberId linkage via linkedEmail fallback
  let resolvedMemberId = data.memberId;
  let resolvedMemberDoc: { id: string; memberId: string; isActive: boolean } | null = null;

  if (!data.memberId) {
    const linked = await findMemberByLinkedEmail(email);
    if (linked && linked.isActive) resolvedMemberId = linked.id;
  } else {
    const memberDoc = await getDoc(doc(db, "members", data.memberId));
    if (memberDoc.exists()) {
      const mData = memberDoc.data();
      if ((mData?.active ?? mData?.isActive) !== false) {
        resolvedMemberDoc = { id: memberDoc.id, memberId: mData?.memberId || "", isActive: (mData?.active ?? mData?.isActive) !== false };
      }
    }
    if (!resolvedMemberDoc) {
      // Stored memberId is stale — try linked email repair
      const linked = await findMemberByLinkedEmail(email);
      if (linked && linked.isActive) {
        resolvedMemberId = linked.id;
        // Fix the user doc so future logins work without the fallback
        await setDoc(doc(db, "users", fbUser.uid), { memberId: resolvedMemberId }, { merge: true });
      }
    }
  }

  if (resolvedMemberDoc || resolvedMemberId) {
    if (resolvedMemberDoc) {
      return {
        appUser: {
          uid: fbUser.uid,
          email: fbUser.email || data.email || "",
          role: "member",
          username: data.username,
          memberId: resolvedMemberDoc.id,
          customMemberId: resolvedMemberDoc.memberId,
          photoUrl: data.photoUrl,
          isTreasurer: data.isTreasurer,
        },
        recognized: true,
      };
    }
    const memberSnap = await getDoc(doc(db, "members", resolvedMemberId!));
    if (memberSnap.exists()) {
      const mData = memberSnap.data();
      if ((mData?.active ?? mData?.isActive) !== false) {
        return {
          appUser: {
            uid: fbUser.uid,
            email: fbUser.email || data.email || "",
            role: "member",
            username: data.username,
            memberId: memberSnap.id,
            customMemberId: mData?.memberId,
            photoUrl: data.photoUrl,
            isTreasurer: data.isTreasurer,
          },
          recognized: true,
        };
      }
      return { appUser: null, recognized: false, error: "Your account has been deactivated. Contact admin." };
    }
  }

  // Fallback: check if a member doc exists with this auth UID as its doc ID
  try {
    const uidMemberSnap = await getDoc(doc(db, "members", fbUser.uid));
    if (uidMemberSnap.exists()) {
      const mData = uidMemberSnap.data();
      if ((mData?.active ?? mData?.isActive) !== false) {
        await setDoc(doc(db, "users", fbUser.uid), {
          username: fbUser.displayName || email.split("@")[0],
          email,
          role: "member",
          memberId: uidMemberSnap.id,
          photoUrl: fbUser.photoURL || "",
          createdAt: new Date().toISOString(),
        });
        return {
          appUser: {
            uid: fbUser.uid,
            email,
            role: "member",
            username: fbUser.displayName || email.split("@")[0],
            memberId: uidMemberSnap.id,
            customMemberId: mData.memberId,
            photoUrl: fbUser.photoURL || undefined,
            isTreasurer: data.isTreasurer,
          },
          recognized: true,
        };
      }
    }
  } catch (err) {
    console.error("[Auth] member-by-uid fallback error:", err);
  }

  return { appUser: null, recognized: false, error: "No member profile linked. Contact admin." };
}

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [firebaseUser, setFirebaseUser] = useState<FirebaseUser | null>(null);
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isRecognized, setIsRecognized] = useState(false);

  const unsubMemberWatcherRef = useRef<(() => void) | null>(null);
  const resolveLockRef = useRef<Promise<void> | null>(null);

  const stopMemberWatcher = useCallback(() => {
    unsubMemberWatcherRef.current?.();
    unsubMemberWatcherRef.current = null;
  }, []);

  const startMemberWatcher = useCallback((memberDocId: string) => {
    stopMemberWatcher();
    const unsub = onSnapshot(doc(db, "members", memberDocId), (snapshot) => {
      if (!snapshot.exists()) {
        setError("Your account has been removed. Contact an admin.");
        setUser(null);
        setIsRecognized(false);
        signOut(auth);
      } else {
        const data = snapshot.data();
        if (!(data?.active ?? data?.isActive)) {
          setError("Your account has been deactivated. Contact an admin.");
          setUser(null);
          setIsRecognized(false);
          signOut(auth);
        }
      }
    });
    unsubMemberWatcherRef.current = unsub;
  }, [stopMemberWatcher]);

  // Session restore on page load/refresh
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (fbUser) => {
      setFirebaseUser(fbUser);
      if (!fbUser) {
        setUser(null);
        setIsRecognized(false);
        setError(null);
        setLoading(false);
        return;
      }

      // Mutex: prevent concurrent resolveUser calls on rapid auth state changes
      while (resolveLockRef.current) {
        await resolveLockRef.current;
      }
      if (user) {
        setLoading(false);
        return;
      }

      const doResolve = async () => {
        try {
          const { appUser, recognized, error: resolveError } = await resolveUser(fbUser);
          setUser(appUser);
          setIsRecognized(recognized);
          setError(resolveError || null);
          if (appUser?.role === "member" && appUser.memberId) {
            startMemberWatcher(appUser.memberId);
          }
        } catch (err: unknown) {
          setError(err instanceof Error ? err.message : "Failed to load user data");
          setUser(null);
          setIsRecognized(false);
        }
      };

      const lock = doResolve();
      resolveLockRef.current = lock;
      try { await lock; } finally { resolveLockRef.current = null; }
      setLoading(false);
    });

    return () => {
      unsub();
      stopMemberWatcher();
    };
  }, [startMemberWatcher, stopMemberWatcher]); // eslint-disable-line react-hooks/exhaustive-deps

  const login = async (email: string, password: string): Promise<AuthResult> => {
    setError(null);
    setLoading(true);

    try {
      const cred = await signInWithEmailAndPassword(auth, email, password);
      const { appUser, recognized, error: resolveError } = await resolveUser(cred.user);

      setUser(appUser);
      setIsRecognized(recognized);
      setError(resolveError || null);
      setLoading(false);

      if (appUser?.role === "member" && appUser.memberId) {
        startMemberWatcher(appUser.memberId);
      }

      if (!appUser) {
        return { success: false, error: resolveError || "Account not recognized. Contact admin." };
      }
      if (!recognized) {
        return { success: true, role: appUser.role };
      }
      if (resolveError) {
        await signOut(auth);
        return { success: false, error: resolveError };
      }
      return { success: true, role: appUser.role };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Login failed";
      setError(message);
      setLoading(false);
      return { success: false, error: message };
    }
  };

  const signInWithGoogle = async (): Promise<AuthResult> => {
    setError(null);
    setLoading(true);

    try {
      const provider = new GoogleAuthProvider();
      const cred = await signInWithPopup(auth, provider);
      const { appUser, recognized, error: resolveError } = await resolveUser(cred.user);

      setUser(appUser);
      setIsRecognized(recognized);
      setError(resolveError || null);
      setLoading(false);

      if (appUser?.role === "member" && appUser.memberId) {
        startMemberWatcher(appUser.memberId);
      }

      if (!appUser) {
        return { success: false, error: resolveError || "Account not recognized. Contact admin." };
      }
      if (!recognized) {
        return { success: true, role: appUser.role };
      }
      if (resolveError) {
        await signOut(auth);
        return { success: false, error: resolveError };
      }
      return { success: true, role: appUser.role };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Google sign-in failed";
      setError(message);
      setLoading(false);
      return { success: false, error: message };
    }
  };

  const joinWithGroupCode = async (code: string): Promise<AuthResult> => {
    setError(null);
    setLoading(true);

    let expectedCode = "LENDWUS";
    try {
      const settingsSnap = await getDoc(doc(db, "app_settings", "fund_settings"));
      if (settingsSnap.exists() && settingsSnap.data().groupCode) {
        expectedCode = String(settingsSnap.data().groupCode).toUpperCase();
      }
    } catch { /* fallback to default */ }

    if (code.toUpperCase() !== expectedCode) {
      setError("Invalid group code. Please try again.");
      setLoading(false);
      return { success: false, error: "Invalid group code." };
    }

    const fbUser = auth.currentUser;
    if (!fbUser || !fbUser.email) {
      setError("You must be signed in first.");
      setLoading(false);
      return { success: false, error: "Not signed in." };
    }

    try {
      let memberDocId: string | undefined;
      let customMemberId: string | undefined;

      await runTransaction(db, async (tx) => {
        const nextId = await generateNextMemberId(db);
        customMemberId = nextId;

        const memberRef = doc(collection(db, "members"));
        memberDocId = memberRef.id;

        tx.set(memberRef, {
          name: fbUser.displayName || fbUser.email!.split("@")[0],
          linkedEmail: fbUser.email,
          headsCount: 1,
          amountPerHead: 500,
          totalRequired: 500,
          joinedAt: serverTimestamp(),
          active: true,
          memberId: customMemberId,
        });

        tx.set(doc(db, "users", fbUser.uid), {
          username: fbUser.displayName || fbUser.email!.split("@")[0],
          email: fbUser.email,
          role: "member",
          memberId: memberRef.id,
          photoUrl: fbUser.photoURL || "",
          createdAt: serverTimestamp(),
        });
      });

      if (memberDocId && customMemberId) {
        setUser({
          uid: fbUser.uid,
          email: fbUser.email,
          role: "member",
          username: fbUser.displayName || fbUser.email!.split("@")[0],
          memberId: memberDocId,
          customMemberId: customMemberId,
          photoUrl: fbUser.photoURL || undefined,
        });
        setError(null);
        setIsRecognized(true);
        setLoading(false);
        startMemberWatcher(memberDocId);
        return { success: true, role: "member" };
      }

      setLoading(false);
      return { success: false, error: "Failed to create member record." };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to join group";
      setError(message);
      setLoading(false);
      return { success: false, error: message };
    }
  };

  const logout = async () => {
    stopMemberWatcher();
    await signOut(auth);
    setUser(null);
    setFirebaseUser(null);
    setIsRecognized(false);
    setError(null);
  };

  const clearError = () => setError(null);

  return (
    <AuthContext.Provider
      value={{ user, firebaseUser, loading, error, isRecognized, login, signInWithGoogle, joinWithGroupCode, logout, clearError }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
};
