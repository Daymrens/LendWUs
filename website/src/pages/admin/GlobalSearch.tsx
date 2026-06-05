import React, { useState, useRef, useEffect } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../../firebase";
import { useNavigate } from "react-router-dom";

interface SearchResult {
  id: string;
  type: "member" | "contribution" | "loan" | "payment" | "loan_request";
  label: string;
  subtitle: string;
  link: string;
}

const GlobalSearch: React.FC<{ onClose: () => void }> = ({ onClose }) => {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    if (!query.trim()) { setResults([]); return; }
    const timer = setTimeout(() => performSearch(query.trim().toLowerCase()), 300);
    return () => clearTimeout(timer);
  }, [query]);

  const performSearch = async (q: string) => {
    setLoading(true);
    try {
      const [memSnap, contSnap, loansSnap, paySnap, loanReqSnap] = await Promise.all([
        getDocs(collection(db, "members")),
        getDocs(collection(db, "contributions")),
        getDocs(collection(db, "loans")),
        getDocs(collection(db, "payment_requests")),
        getDocs(collection(db, "loan_requests")),
      ]);

      const names: Record<string, string> = {};
      memSnap.docs.forEach(d => { names[d.id] = d.data().name || d.id; });

      const found: SearchResult[] = [];

      memSnap.docs.forEach(d => {
        const m = d.data() as Record<string, unknown>;
        const name = (m.name as string) || "";
        const email = (m.linkedEmail as string) || "";
        if (name.toLowerCase().includes(q) || email.toLowerCase().includes(q)) {
          found.push({ id: d.id, type: "member", label: name, subtitle: `₱${(Number(m.balance) || 0).toLocaleString()} • ${m.headsCount || 0} heads`, link: `/admin/members/${d.id}` });
        }
      });

      contSnap.docs.forEach(d => {
        const c = d.data() as Record<string, unknown>;
        const memberName = names[c.memberId as string] || "";
        const amt = String(Number(c.amount) || 0);
        if (memberName.toLowerCase().includes(q) || amt.includes(q)) {
          found.push({ id: d.id, type: "contribution", label: `₱${(Number(c.amount) || 0).toLocaleString()} contribution`, subtitle: memberName, link: `/admin/members/${c.memberId}` });
        }
      });

      loansSnap.docs.forEach(d => {
        const l = d.data() as Record<string, unknown>;
        const memberName = names[l.memberId as string] || "";
        const amt = String(Number(l.principal) || 0);
        if (memberName.toLowerCase().includes(q) || amt.includes(q)) {
          found.push({ id: d.id, type: "loan", label: `₱${(Number(l.principal) || 0).toLocaleString()} loan`, subtitle: memberName, link: `/admin/members/${l.memberId}` });
        }
      });

      paySnap.docs.forEach(d => {
        const p = d.data() as Record<string, unknown>;
        const memberName = names[p.memberId as string] || "";
        if (memberName.toLowerCase().includes(q) || String(Number(p.amount) || 0).includes(q)) {
          found.push({ id: d.id, type: "payment", label: `₱${(Number(p.amount) || 0).toLocaleString()} ${p.type === "loan" ? "repayment" : "payment"}`, subtitle: `${memberName} • ${p.status as string}`, link: `/admin/members/${p.memberId}` });
        }
      });

      loanReqSnap.docs.forEach(d => {
        const r = d.data() as Record<string, unknown>;
        const name = (r.memberName as string) || names[r.memberId as string] || "";
        if (name.toLowerCase().includes(q) || String(Number(r.amount) || 0).includes(q)) {
          found.push({ id: d.id, type: "loan_request", label: `₱${(Number(r.amount) || 0).toLocaleString()} loan request`, subtitle: name, link: "/admin/approvals" });
        }
      });

      setResults(found.slice(0, 20));
    } catch {
      setResults([]);
    } finally {
      setLoading(false);
    }
  };

  const handleSelect = (r: SearchResult) => {
    onClose();
    navigate(r.link);
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="global-search-modal" onClick={e => e.stopPropagation()}>
        <input
          ref={inputRef}
          type="text"
          className="search-input"
          placeholder="Search members, contributions, loans, payments..."
          value={query}
          onChange={e => setQuery(e.target.value)}
          style={{ marginBottom: 0, fontSize: 16, padding: "12px 16px" }}
        />
        <div className="global-search-results">
          {loading ? (
            <div className="admin-loading" style={{ padding: 40 }}><div className="spinner" /></div>
          ) : results.length === 0 && query.trim() ? (
            <p className="empty-text" style={{ padding: 32 }}>No results for "{query}"</p>
          ) : results.length === 0 ? (
            <p className="empty-text" style={{ padding: 32 }}>Start typing to search...</p>
          ) : (
            results.map((r, i) => (
              <div key={`${r.type}-${r.id}-${i}`} className="global-search-item" onClick={() => handleSelect(r)}>
                <div className="search-item-icon">
                  {r.type === "member" ? "👤" : r.type === "contribution" ? "💰" : r.type === "loan" ? "💳" : r.type === "payment" ? "💵" : "📋"}
                </div>
                <div className="search-item-info">
                  <div className="search-item-label">{r.label}</div>
                  <div className="search-item-subtitle">{r.subtitle}</div>
                </div>
                <span className="search-item-badge">{r.type.replace("_", " ")}</span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};

export default GlobalSearch;
