import { getDoc, doc, getDocs, collection, query, where } from "firebase/firestore";

export interface PopupMessage {
  title: string;
  message: string;
  category?: string;
}

export const defaultPopups: PopupMessage[] = [
  // General tips
  { title: '💡 Did You Know?', message: 'You can request a head count change anytime through the app under Requests.', category: 'general' },
  { title: '📈 Fund Growth', message: 'Your contributions help the fund grow. The more members contribute, the bigger the loan pool for everyone!', category: 'general' },
  { title: '👥 Invite Family', message: 'The more active members we have, the faster the fund grows. Encourage family to join!', category: 'general' },
  { title: '📱 Stay Updated', message: 'Enable notifications to get alerts on approvals, confirmations, and fund updates.', category: 'general' },
  // Security
  { title: '🔒 Quick Access', message: 'Enable biometric login in Settings for faster, secure sign-in without typing your password.', category: 'security' },
  { title: '🔐 Secure Your Account', message: 'Use a strong password and never share your login credentials with anyone.', category: 'security' },
  // Loan-specific
  { title: '💰 Loan Repayment Due', message: 'You have an active loan! Make sure to pay on time to keep the fund healthy.', category: 'loan' },
  { title: '📊 Track Your Loans', message: 'View your loan balance, payment history, and repayment schedule anytime in the Loans tab.', category: 'loan' },
  { title: '⏰ Pay Before Due Date', message: 'Paying your loan early saves on interest and makes funds available for other members.', category: 'loan' },
  { title: '📋 Need Help With Repayment?', message: "If you're having trouble with repayment, talk to the admin about extending your due date.", category: 'loan' },
  // Savings
  { title: '⏰ Contribution Reminder', message: "Don't forget to pay your monthly contribution on time to stay in good standing!", category: 'savings' },
  { title: '🎯 Double Your Savings', message: 'Consistent contributions every cutoff mean bigger returns at year-end.', category: 'savings' },
  { title: '📊 Monitor Your Progress', message: 'Check your contribution history and payment status on the dashboard to stay on track.', category: 'savings' },
];

export function getRandomPopup(popups: PopupMessage[], hasActiveLoan?: boolean): PopupMessage {
  if (hasActiveLoan) {
    const loan = popups.filter(p => p.category === 'loan');
    if (loan.length > 0) return loan[Math.floor(Math.random() * loan.length)];
  }
  return popups[Math.floor(Math.random() * popups.length)];
}

export async function fetchPopupsFromFirestore(db: any): Promise<PopupMessage[]> {
  try {
    const docSnap = await getDoc(doc(db, 'app_settings', 'popup_messages'));
    if (docSnap.exists() && docSnap.data().messages) {
      const custom = docSnap.data().messages as PopupMessage[];
      return [...defaultPopups, ...custom];
    }
  } catch (e) {}
  return defaultPopups;
}
