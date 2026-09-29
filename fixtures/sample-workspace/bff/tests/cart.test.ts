import { getPriceCents } from "../src/services/catalog";

describe("catalog prices", () => {
  it("returns the price of a known product", () => {
    expect(getPriceCents("p1")).toBe(4990);
  });
  it("throws on unknown product", () => {
    expect(() => getPriceCents("nope")).toThrow();
  });
});
