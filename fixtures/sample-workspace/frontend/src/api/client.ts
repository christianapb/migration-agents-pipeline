import { getSession, setSession } from "../store/session";

async function refresh(): Promise<boolean> {
  const s = getSession();
  if (!s) return false;
  const res = await fetch("/api/auth/refresh", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken: s.refreshToken }),
  });
  if (!res.ok) {
    setSession(null);
    return false;
  }
  const { accessToken } = await res.json();
  setSession({ ...s, accessToken });
  return true;
}

export async function api(path: string, init: RequestInit = {}, retry = true): Promise<Response> {
  const s = getSession();
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  if (s) headers.set("Authorization", `Bearer ${s.accessToken}`);
  const res = await fetch(`/api${path}`, { ...init, headers });
  if (res.status === 401 && retry && (await refresh())) return api(path, init, false);
  if (res.status === 401) window.location.assign("/login");
  return res;
}
