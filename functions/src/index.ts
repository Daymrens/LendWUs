import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

const VALID_GROUP_CODE = "LENDWUS";
const db = admin.firestore();

// ─── helpers ──────────────────────────────────────────────────

async function getUserTokenByMemberId(memberId: string): Promise<string | null> {
  const snap = await db
    .collection("users")
    .where("memberId", "==", memberId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].data().fcmToken ?? null;
}

async function getAdminTokens(): Promise<string[]> {
  const snap = await db
    .collection("users")
    .where("role", "==", "admin")
    .get();
  return snap.docs
    .map((d) => d.data().fcmToken as string | undefined)
    .filter((t): t is string => !!t);
}

async function sendPush(token: string, title: string, body: string, data?: Record<string, string>) {
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: data ?? {},
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (e) {
    console.warn(`FCM send failed for token ${token.slice(0, 8)}…:`, e);
  }
}

async function notifyMember(
  memberId: string,
  title: string,
  body: string,
  data?: Record<string, string>,
) {
  const token = await getUserTokenByMemberId(memberId);
  if (token) await sendPush(token, title, body, data);
}

async function notifyAdmins(title: string, body: string, data?: Record<string, string>) {
  const tokens = await getAdminTokens();
  await Promise.allSettled(tokens.map((t) => sendPush(t, title, body, data)));
}

function toTitle(str: string): string {
  return str
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

// ─── Firestore triggers: notify member on status change ───────

export const onPaymentRequestUpdate = functions.firestore
  .document("payment_requests/{docId}")
  .onUpdate(async (change, _ctx) => {
    const before = change.before.data()!;
    const after = change.after.data()!;
    if (before.status === after.status) return;

    const memberId = after.memberId;
    const amount = after.amount;
    const status = toTitle(after.status);

    await notifyMember(
      memberId,
      "Payment Request Updated",
      `Your ₱${amount.toFixed(2)} payment was ${status.toLowerCase()}.`,
      { route: "/requests", type: "payment" },
    );
  });

export const onLoanRequestUpdate = functions.firestore
  .document("loan_requests/{docId}")
  .onUpdate(async (change, _ctx) => {
    const before = change.before.data()!;
    const after = change.after.data()!;
    if (before.status === after.status) return;

    const memberId = after.memberId;
    const amount = after.amount;
    const status = toTitle(after.status);

    await notifyMember(
      memberId,
      "Loan Request Updated",
      `Your ₱${amount.toFixed(2)} loan was ${status.toLowerCase()}.`,
      { route: "/requests", type: "loan" },
    );
  });

export const onHeadChangeRequestUpdate = functions.firestore
  .document("head_change_requests/{docId}")
  .onUpdate(async (change, _ctx) => {
    const before = change.before.data()!;
    const after = change.after.data()!;
    if (before.status === after.status) return;

    const memberId = after.memberId;
    const requested = after.requestedHeads;
    const status = toTitle(after.status);

    await notifyMember(
      memberId,
      "Head Change Request Updated",
      `Your request for ${requested} heads was ${status.toLowerCase()}.`,
      { route: "/requests", type: "heads" },
    );
  });

// ─── Firestore triggers: notify admins on new request ─────────

export const onPaymentRequestCreate = functions.firestore
  .document("payment_requests/{docId}")
  .onCreate(async (snap, _ctx) => {
    const data = snap.data()!;
    const memberName = data.memberName || "A member";
    const amount = data.amount;

    await notifyAdmins(
      "New Payment Request",
      `${memberName} submitted ₱${amount.toFixed(2)} for approval.`,
      { route: "/approvals", type: "payment" },
    );
  });

export const onLoanRequestCreate = functions.firestore
  .document("loan_requests/{docId}")
  .onCreate(async (snap, _ctx) => {
    const data = snap.data()!;
    const memberName = data.memberName ?? "A member";
    const amount = data.amount;

    await notifyAdmins(
      "New Loan Request",
      `${memberName} requested ₱${amount.toFixed(2)} loan.`,
      { route: "/approvals", type: "loan" },
    );
  });

export const onHeadChangeRequestCreate = functions.firestore
  .document("head_change_requests/{docId}")
  .onCreate(async (snap, _ctx) => {
    const data = snap.data()!;
    const memberName = data.memberName ?? "A member";
    const requested = data.requestedHeads;

    await notifyAdmins(
      "New Head Change Request",
      `${memberName} wants ${requested} heads.`,
      { route: "/approvals", type: "heads" },
    );
  });

// ─── existing callable ────────────────────────────────────────

function formatMemberId(n: number): string {
  if (!Number.isInteger(n) || n < 1 || n > 999999) {
    throw new Error(`MemberID number out of range (got ${n})`);
  }
  return `LWS${String(n).padStart(6, "0")}`;
}

async function generateNextMemberId(): Promise<string> {
  const counterRef = db.doc("meta/member_counter");
  return db.runTransaction(async (tx) => {
    const counter = await tx.get(counterRef);
    const existingMax = (counter.data()?.lastNumber as number | undefined) ?? 0;
    const start = existingMax + 1;
    if (start > 999999) {
      throw new Error("MemberID limit reached (max 999999)");
    }
    tx.set(counterRef, {
      lastNumber: start,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return formatMemberId(start);
  });
}

export const joinWithGroupCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be signed in");
  }

  const groupCode: string | undefined = data.groupCode;
  if (!groupCode || groupCode.toUpperCase() !== VALID_GROUP_CODE) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid group code");
  }

  const auth = context.auth;
  const email = context.auth.token.email;
  if (!email) {
    throw new functions.https.HttpsError("failed-precondition", "User must have an email");
  }

  const existingUserDoc = await db.collection("users").doc(auth.uid).get();
  if (existingUserDoc.exists) {
    throw new functions.https.HttpsError("already-exists", "User already registered");
  }

  const displayName: string | undefined = data.name;
  const memberId = await generateNextMemberId();

  const memberRef = await db.collection("members").add({
    memberId,
    name: displayName || email.split("@")[0],
    linkedEmail: email,
    headsCount: 1,
    amountPerHead: 500.0,
    totalRequired: 500.0,
    isActive: true,
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection("users").doc(auth.uid).set({
    email: email,
    role: "member",
    memberId: memberRef.id,
    photoUrl: data.photoUrl || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    memberId: memberRef.id,
    publicId: memberId,
  };
});
