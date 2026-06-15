import React, { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../../firebase";

interface BalanceItem {
  id: string;
  name: string;
  balance: number;
  totalPaid: number;
}

const MemberBalances: React.FC = () => {
  const [items, setItems] = useState<BalanceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    loadBalances();
  }, []);

  const loadBalances = async () => {
    setLoading(true);
    setError("");
    try {
      const mSnap = await getDocs(collection(db, "members"));
      const cSnap = await getDocs(collection(db, "contributions"));
      const pSnap = await getDocs(collection(db, "payment_requests"));

      const contribTotals: Record<string, number> = {};
      cSnap.docs.forEach(d => {
        const data = d.data();
        const mid = data.memberId as string;
        contribTotals[mid] = (contribTotals[mid] || 0) + (Number(data.amount) || 0);
      });

      const paymentTotals: Record<string, number> = {};
      pSnap.docs.forEach(d => {
        const data = d.data();
        if (data.status === "approved") {
          const mid = data.memberId as string;
          paymentTotals[mid] = (paymentTotals[mid] || 0) + (Number(data.amount) || 0);
        }
      });

      const list: BalanceItem[] = mSnap.docs.map(d => {
        const data = d.data();
        const mid = d.id;
        const totalPaid = (contribTotals[mid] || 0) + (paymentTotals[mid] || 0);
        return {
          id: mid,
          name: (data.name as string) || "Unknown",
          balance: Number(data.balance) || 0,
          totalPaid,
        };
      });

      list.sort((a, b) => b.balance - a.balance);
      setItems(list);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load balances");
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading balances...</p></div>;
  if (error) return <div className="admin-error"><p>{error}</p></div>;

  return (
    <div className="page-container">
      <div className="page-header">
        <h1>Member Balances</h1>
        <button className="btn btn-outline btn-sm" onClick={loadBalances}>Refresh</button>
      </div>
      {items.length === 0 ? (
        <p className="empty-text">No members found</p>
      ) : (
        <div className="member-balances-list">
          {items.map((item, i) => (
            <div key={item.id} className="member-card">
              <div className="member-info">
                <div className="member-balance-rank" style={{
                  width: 32, height: 32, borderRadius: "50%",
                  display: "flex", alignItems: "center", justifyContent: "center",
                  background: item.balance > 0 ? "rgba(34,197,94,0.15)" : "rgba(139,148,158,0.15)",
                  color: item.balance > 0 ? "#22c55e" : "#8b949e",
                  fontWeight: 700, fontSize: 14,
                }}>{i + 1}</div>
                <div style={{ marginLeft: 12, flex: 1 }}>
                  <div style={{ fontWeight: 600 }}>{item.name}</div>
                  <div style={{ fontSize: 13, color: "#8b949e" }}>
                    Total paid: ₱{item.totalPaid.toLocaleString()}
                  </div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <div style={{ fontSize: 11, color: "#8b949e80" }}>Credit Balance</div>
                  <div style={{
                    fontWeight: 700, fontSize: 15,
                    color: item.balance > 0 ? "#22c55e" : "#8b949e",
                  }}>
                    ₱{item.balance.toLocaleString()}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default MemberBalances;
