import React, { useEffect, useRef, useState } from 'react';
import { getFirestore, collection, query, where, getDocs } from 'firebase/firestore';
import { PopupMessage, fetchPopupsFromFirestore, getRandomPopup } from '../utils/popupMessages';
import { useAuth } from '../context/AuthContext';

interface Props {
  children: React.ReactNode;
}

const todayString = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const PopupOverlay: React.FC<Props> = ({ children }) => {
  const { user } = useAuth();
  const [popup, setPopup] = useState<PopupMessage | null>(null);
  const [dontShowAgain, setDontShowAgain] = useState(false);
  const shownRef = useRef(false);
  const hasActiveLoanRef = useRef(false);

  useEffect(() => {
    if (shownRef.current) return;
    shownRef.current = true;

    const dismissed = localStorage.getItem('popup_dismissed_date');
    if (dismissed === todayString()) return;

    const db = getFirestore();

    (async () => {
      let hasLoan = false;
      if (user?.memberId) {
        try {
          const loanSnap = await getDocs(
            query(collection(db, 'loans'), where('memberId', '==', user.memberId), where('isFullyRepaid', '==', false))
          );
          hasLoan = !loanSnap.empty;
        } catch {}
      }
      hasActiveLoanRef.current = hasLoan;

      const all = await fetchPopupsFromFirestore(db);
      setPopup(getRandomPopup(all, hasLoan));
    })();
  }, [user?.memberId]);

  const handleDismiss = () => {
    if (dontShowAgain) {
      localStorage.setItem('popup_dismissed_date', todayString());
    }
    setPopup(null);
  };

  if (!popup) return <>{children}</>;

  return (
    <>
      <div className="popup-overlay-backdrop" onClick={() => setPopup(null)} />
      <div className="popup-overlay-card">
        <div className="popup-icon">💡</div>
        <h3 className="popup-title">{popup.title}</h3>
        <p className="popup-message">{popup.message}</p>
        <label className="popup-dont-show" onClick={e => e.stopPropagation()}>
          <input
            type="checkbox"
            checked={dontShowAgain}
            onChange={e => setDontShowAgain(e.target.checked)}
          />
          <span>Don't show again today</span>
        </label>
        <div style={{ height: 12 }} />
        <button className="popup-button" onClick={handleDismiss}>Got it!</button>
      </div>
      {children}
    </>
  );
};

export default PopupOverlay;
