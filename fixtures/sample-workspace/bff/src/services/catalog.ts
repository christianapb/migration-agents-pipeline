export interface Product {
  id: string;
  name: string;
  priceCents: number;
  hidden: boolean;
}

const PRODUCTS: Product[] = [
  { id: "p1", name: "Teclado", priceCents: 4990, hidden: false },
  { id: "p2", name: "Mouse", priceCents: 1990, hidden: false },
  { id: "p3", name: "Monitor (descontinuado)", priceCents: 0, hidden: true },
];

export function listProducts(): Product[] {
  return PRODUCTS.filter((p) => !p.hidden);
}

export function findProduct(id: string): Product | undefined {
  return PRODUCTS.find((p) => p.id === id);
}

export function getPriceCents(id: string): number {
  const p = findProduct(id);
  if (!p) throw new Error(`unknown product ${id}`);
  return p.priceCents;
}
