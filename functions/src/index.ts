import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

const VALID_GROUP_CODE = "LENDWUS";

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

  const db = admin.firestore();

  const existingUserDoc = await db.collection("users").doc(auth.uid).get();
  if (existingUserDoc.exists) {
    throw new functions.https.HttpsError("already-exists", "User already registered");
  }

  const displayName: string | undefined = data.name;
  const memberRef = await db.collection("members").add({
    name: displayName || email.split("@")[0],
    linkedEmail: email,
    headsCount: 1,
    amountPerHead: 150.0,
    totalRequired: 150.0,
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
  };
});
