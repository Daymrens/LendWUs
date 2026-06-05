"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.joinWithGroupCode = exports.onHeadChangeRequestCreate = exports.onLoanRequestCreate = exports.onPaymentRequestCreate = exports.onHeadChangeRequestUpdate = exports.onLoanRequestUpdate = exports.onPaymentRequestUpdate = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const VALID_GROUP_CODE = "LENDWUS";
const db = admin.firestore();
// ─── helpers ──────────────────────────────────────────────────
async function getUserTokenByMemberId(memberId) {
    var _a;
    const snap = await db
        .collection("users")
        .where("memberId", "==", memberId)
        .limit(1)
        .get();
    if (snap.empty)
        return null;
    return (_a = snap.docs[0].data().fcmToken) !== null && _a !== void 0 ? _a : null;
}
async function getAdminTokens() {
    const snap = await db
        .collection("users")
        .where("role", "==", "admin")
        .get();
    return snap.docs
        .map((d) => d.data().fcmToken)
        .filter((t) => !!t);
}
async function sendPush(token, title, body, data) {
    if (!token)
        return;
    try {
        await admin.messaging().send({
            token,
            notification: { title, body },
            data: data !== null && data !== void 0 ? data : {},
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
        });
    }
    catch (e) {
        console.warn(`FCM send failed for token ${token.slice(0, 8)}…:`, e);
    }
}
async function notifyMember(memberId, title, body, data) {
    const token = await getUserTokenByMemberId(memberId);
    if (token)
        await sendPush(token, title, body, data);
}
async function notifyAdmins(title, body, data) {
    const tokens = await getAdminTokens();
    await Promise.allSettled(tokens.map((t) => sendPush(t, title, body, data)));
}
function toTitle(str) {
    return str
        .replace(/_/g, " ")
        .replace(/\b\w/g, (c) => c.toUpperCase());
}
// ─── Firestore triggers: notify member on status change ───────
exports.onPaymentRequestUpdate = functions.firestore
    .document("payment_requests/{docId}")
    .onUpdate(async (change, _ctx) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return;
    const memberId = after.memberId;
    const amount = after.amount;
    const status = toTitle(after.status);
    await notifyMember(memberId, "Payment Request Updated", `Your ₱${amount.toFixed(2)} payment was ${status.toLowerCase()}.`, { route: "/requests", type: "payment" });
});
exports.onLoanRequestUpdate = functions.firestore
    .document("loan_requests/{docId}")
    .onUpdate(async (change, _ctx) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return;
    const memberId = after.memberId;
    const amount = after.amount;
    const status = toTitle(after.status);
    await notifyMember(memberId, "Loan Request Updated", `Your ₱${amount.toFixed(2)} loan was ${status.toLowerCase()}.`, { route: "/requests", type: "loan" });
});
exports.onHeadChangeRequestUpdate = functions.firestore
    .document("head_change_requests/{docId}")
    .onUpdate(async (change, _ctx) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return;
    const memberId = after.memberId;
    const requested = after.requestedHeads;
    const status = toTitle(after.status);
    await notifyMember(memberId, "Head Change Request Updated", `Your request for ${requested} heads was ${status.toLowerCase()}.`, { route: "/requests", type: "heads" });
});
// ─── Firestore triggers: notify admins on new request ─────────
exports.onPaymentRequestCreate = functions.firestore
    .document("payment_requests/{docId}")
    .onCreate(async (snap, _ctx) => {
    const data = snap.data();
    const memberName = data.memberName || "A member";
    const amount = data.amount;
    await notifyAdmins("New Payment Request", `${memberName} submitted ₱${amount.toFixed(2)} for approval.`, { route: "/approvals", type: "payment" });
});
exports.onLoanRequestCreate = functions.firestore
    .document("loan_requests/{docId}")
    .onCreate(async (snap, _ctx) => {
    var _a;
    const data = snap.data();
    const memberName = (_a = data.memberName) !== null && _a !== void 0 ? _a : "A member";
    const amount = data.amount;
    await notifyAdmins("New Loan Request", `${memberName} requested ₱${amount.toFixed(2)} loan.`, { route: "/approvals", type: "loan" });
});
exports.onHeadChangeRequestCreate = functions.firestore
    .document("head_change_requests/{docId}")
    .onCreate(async (snap, _ctx) => {
    var _a;
    const data = snap.data();
    const memberName = (_a = data.memberName) !== null && _a !== void 0 ? _a : "A member";
    const requested = data.requestedHeads;
    await notifyAdmins("New Head Change Request", `${memberName} wants ${requested} heads.`, { route: "/approvals", type: "heads" });
});
// ─── existing callable ────────────────────────────────────────
function formatMemberId(n) {
    if (!Number.isInteger(n) || n < 1 || n > 999999) {
        throw new Error(`MemberID number out of range (got ${n})`);
    }
    return `LWS${String(n).padStart(6, "0")}`;
}
async function generateNextMemberId() {
    const counterRef = db.doc("meta/member_counter");
    return db.runTransaction(async (tx) => {
        var _a, _b;
        const counter = await tx.get(counterRef);
        const existingMax = (_b = (_a = counter.data()) === null || _a === void 0 ? void 0 : _a.lastNumber) !== null && _b !== void 0 ? _b : 0;
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
exports.joinWithGroupCode = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be signed in");
    }
    const groupCode = data.groupCode;
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
    const displayName = data.name;
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
//# sourceMappingURL=index.js.map