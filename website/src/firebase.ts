// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBf-zD5S7bAcaOAroIgcoLKBB3BMcCrU5Q",
  authDomain: "lmsystemm.firebaseapp.com",
  projectId: "lmsystemm",
  storageBucket: "lmsystemm.firebasestorage.app",
  messagingSenderId: "55723804965",
  appId: "1:55723804965:web:3d694a841165a235e2b2cc",
  measurementId: "G-LJT0L350VC"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
export const analytics = typeof window !== "undefined" ? getAnalytics(app) : null;
export default app;
