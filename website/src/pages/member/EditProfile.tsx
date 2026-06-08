import React, { useState } from "react";
import {
  doc,
  updateDoc,
} from "firebase/firestore";
import { db } from "../../firebase";
import { useMemberAuth } from "../../context/MemberAuthContext";

const EditProfile: React.FC = () => {
  const { user } = useMemberAuth();
  const [displayName, setDisplayName] = useState(user?.username || "");
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!displayName.trim()) return;
    setSubmitting(true);
    setMessage("");
    try {
      if (user?.uid) {
        await updateDoc(doc(db, "users", user.uid), { username: displayName.trim() });
        setMessage("Profile updated successfully.");
      } else {
        setMessage("User not found.");
      }
    } catch (err: unknown) {
      setMessage(err instanceof Error ? err.message : "Failed to update");
    } finally { setSubmitting(false); }
  };

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>Edit Profile</h1>
      </div>

      <div className="settings-section">
        <h2>Profile Information</h2>
        {message && (
          <div className={`message ${message.includes("success") ? "success" : "error"}`}>
            {message}
          </div>
        )}
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Display Name</label>
            <input type="text" value={displayName} onChange={e => setDisplayName(e.target.value)} required />
          </div>
          <div className="form-group">
            <label>Email</label>
            <input type="email" value={user?.email || ""} disabled />
          </div>
          <div className="modal-actions">
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? "Saving..." : "Save Changes"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default EditProfile;
