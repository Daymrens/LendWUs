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
exports.joinWithGroupCode = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const VALID_GROUP_CODE = "LENDWUS";
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
    const db = admin.firestore();
    const existingUserDoc = await db.collection("users").doc(auth.uid).get();
    if (existingUserDoc.exists) {
        throw new functions.https.HttpsError("already-exists", "User already registered");
    }
    const displayName = data.name;
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
//# sourceMappingURL=index.js.map