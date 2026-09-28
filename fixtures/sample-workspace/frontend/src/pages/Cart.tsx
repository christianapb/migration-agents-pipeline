import { useEffect, useState } from "react";
import { api } from "../api/client";

interface Line {
  productId: string;
  qty: number;
  unitPriceCents: number;
}

export function Cart() {
  const [lines, setLines] = useState<Line[]>([]);
  const [total, setTotal] = useState(0);

  async function load() {
    const b = await api("/cart").then((r) => r.json());
    setLines(b.items);
    setTotal(b.totalCents);
  }

  useEffect(() => {
    load();
  }, []);

  async function remove(id: string) {
    await api(`/cart/items/${id}`, { method: "DELETE" });
    await load();
  }

  return (
    <div>
      <ul>
        {lines.map((l) => (
          <li key={l.productId}>
            {l.productId} × {l.qty} — ${((l.unitPriceCents * l.qty) / 100).toFixed(2)}
            <button onClick={() => remove(l.productId)}>Quitar</button>
          </li>
        ))}
      </ul>
      <p>Total: ${(total / 100).toFixed(2)}</p>
    </div>
  );
}
