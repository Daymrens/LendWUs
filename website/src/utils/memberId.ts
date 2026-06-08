import { doc, runTransaction, serverTimestamp, writeBatch, collection, getDocs, getDoc, setDoc, type Firestore } from "firebase/firestore";

export const MEMBER_ID_PREFIX = "LWS";
export const MEMBER_ID_PADDING = 6;
const COUNTER_DOC = "meta/member_counter";
const BACKFILL_FLAG_DOC = "meta/member_ids_backfilled";

export function formatMemberId(n: number): string {
  if (!Number.isInteger(n) || n < 1) {
    throw new Error(`MemberID number must be a positive integer (got ${n})`);
  }
  if (n > 999999) {
    throw new Error(`MemberID number exceeds 6 digits (max 999999, got ${n})`);
  }
  return `${MEMBER_ID_PREFIX}${String(n).padStart(MEMBER_ID_PADDING, "0")}`;
}

export function parseMemberId(value: string | null | undefined): number | null {
  if (!value) return null;
  if (!value.startsWith(MEMBER_ID_PREFIX)) return null;
  const tail = value.substring(MEMBER_ID_PREFIX.length);
  const n = Number(tail);
  return Number.isInteger(n) ? n : null;
}

export function maxExistingNumber(memberIds: Array<string | null | undefined>): number {
  let maxN = 0;
  for (const id of memberIds) {
    const n = parseMemberId(id ?? null);
    if (n !== null && n > maxN) maxN = n;
  }
  return maxN;
}

export async function generateNextMemberId(db: Firestore): Promise<string> {
  const ids = await generateNextMemberIds(db, 1);
  return ids[0];
}

export async function generateNextMemberIds(db: Firestore, count: number): Promise<string[]> {
  if (count <= 0) return [];
  return runTransaction(db, async (tx) => {
    const counterRef = doc(db, COUNTER_DOC);
    const counter = await tx.get(counterRef);
    const existingMax = (counter.data()?.lastNumber as number | undefined) ?? 0;
    const start = existingMax + 1;
    const end = start + count - 1;
    if (end > 999999) {
      throw new Error("MemberID limit reached (max 999999)");
    }
    tx.set(counterRef, { lastNumber: end, updatedAt: serverTimestamp() });
    return Array.from({ length: count }, (_, i) => formatMemberId(start + i));
  });
}

export async function backfillMissingMemberIds(db: Firestore): Promise<number> {
  const flagRef = doc(db, BACKFILL_FLAG_DOC);
  const flag = await getDoc(flagRef);
  if (flag.data()) return 0;

  const snap = await getDocs(collection(db, "members"));
  const missing = snap.docs
    .filter((d) => !(d.data().memberId as string | undefined))
    .sort((a, b) => {
      const aData = a.data();
      const bData = b.data();

      const getMillis = (val: any) => {
        if (!val) return 0;
        if (val.toMillis) return val.toMillis();
        if (val instanceof Date) return val.getTime();
        if (typeof val === "string") return new Date(val).getTime();
        return 0;
      };

      const at = getMillis(aData.joinedAt);
      const bt = getMillis(bData.joinedAt);
      return at - bt;
    });

  if (missing.length === 0) {
    await setDoc(flagRef, { at: serverTimestamp() });
    return 0;
  }

  let cursor = maxExistingNumber(snap.docs.map((d) => d.data().memberId as string | undefined));
  const batch = writeBatch(db);
  for (const m of missing) {
    cursor += 1;
    batch.update(m.ref, { memberId: formatMemberId(cursor) });
  }
  batch.set(doc(db, COUNTER_DOC), { lastNumber: cursor, updatedAt: serverTimestamp() });
  await batch.commit();
  await setDoc(flagRef, { at: serverTimestamp() });
  return missing.length;
}
