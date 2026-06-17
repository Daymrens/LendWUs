import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getAuth, setPersistence, browserLocalPersistence } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyBf-zD5S7bAcaOAroIgcoLKBB3BMcCrU5Q",
  authDomain: "lmsystemm.firebaseapp.com",
  projectId: "lmsystemm",
  storageBucket: "lmsystemm.firebasestorage.app",
  messagingSenderId: "55723804965",
  appId: "1:55723804965:web:3d694a841165a235e2b2cc",
  measurementId: "G-LJT0L350VC"
};

const app = initializeApp(firebaseConfig);
export const analytics = typeof window !== "undefined" ? getAnalytics(app) : null;
export const auth = getAuth(app);
setPersistence(auth, browserLocalPersistence);
export const db = getFirestore(app);
export const functions = getFunctions(app, "asia-east2");
export const storage = getStorage(app);
export default app;
