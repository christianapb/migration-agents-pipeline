import { useEffect, useState } from "react";
import { api } from "../api/client";

interface Product {
  id: string;
  name: string;
  priceCents: number;
}

export function Products() {
  const [items, setItems] = useState<Product[]>([]);

  useEffect(() => {
    api("/products").then((r) => r.json()).then((b) => setItems(b.items));
  }, []);

  async function add(id: string) {
    await api("/cart/items", { method: "POST", body: JSON.stringify({ productId: id, qty: 1 }) });
  }

  return (
    <ul>
      {items.map((p) => (
        <li key={p.id}>
          {p.name} — ${(p.priceCents / 100).toFixed(2)}
          <button onClick={() => add(p.id)}>Agregar</button>
        </li>
      ))}
    </ul>
  );
}
