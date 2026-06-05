import React, { createContext, useContext, useEffect, useState } from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  User as FirebaseUser,
} from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "../firebase";

export interface AppUser {
  uid: string;
  email: string;
  role: "admin" | "member";
  username?: string;
  memberId?: string;
  photoUrl?: string;
}

interface AuthContextType {
  user: AppUser | null;
  firebaseUser: FirebaseUser | null;
  loading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [firebaseUser, setFirebaseUser] = useState<FirebaseUser | null>(null);
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (fbUser) => {
      setFirebaseUser(fbUser);
      if (fbUser) {
        try {
          const userDoc = await getDoc(doc(db, "users", fbUser.uid));
          if (userDoc.exists()) {
            const data = userDoc.data();
            const appUser: AppUser = {
              uid: fbUser.uid,
              email: fbUser.email || data.email || "",
              role: (data.role as "admin" | "member") || "member",
              username: data.username,
              memberId: data.memberId,
              photoUrl: data.photoUrl,
            };
            setUser(appUser);
            if (appUser.role !== "admin") {
              setError("Access denied. Admin account required.");
              await signOut(auth);
              setUser(null);
              setFirebaseUser(null);
            } else {
              setError(null);
            }
          } else {
            setError("User record not found.");
            await signOut(auth);
            setUser(null);
            setFirebaseUser(null);
          }
        } catch (err: unknown) {
          const message = err instanceof Error ? err.message : "Failed to load user data";
          setError(message);
          setUser(null);
        }
      } else {
        setUser(null);
        setError(null);
      }
      setLoading(false);
    });
    return unsub;
  }, []);

  const login = async (email: string, password: string) => {
    setError(null);
    setLoading(true);
    try {
      const result = await signInWithEmailAndPassword(auth, email, password);
      const userDoc = await getDoc(doc(db, "users", result.user.uid));
      if (userDoc.exists()) {
        const data = userDoc.data();
        if (data.role !== "admin") {
          await signOut(auth);
          throw new Error("Access denied. Admin account required.");
        }
      } else {
        await signOut(auth);
        throw new Error("User record not found in database.");
      }
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Login failed";
      setError(message);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    await signOut(auth);
    setUser(null);
    setFirebaseUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, firebaseUser, loading, error, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
};
