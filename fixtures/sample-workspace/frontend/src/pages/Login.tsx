import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api/client";
import { setSession } from "../store/session";

export function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const res = await api("/auth/login", { method: "POST", body: JSON.stringify({ email, password }) });
    if (!res.ok) {
      const body = await res.json().catch(() => null);
      setError(body?.error?.code === "BAD_CREDENTIALS" ? "Correo o contraseña incorrectos" : "Error inesperado");
      return;
    }
    setSession(await res.json());
    navigate("/");
  }

  return (
    <form onSubmit={onSubmit}>
      <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Correo" />
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Contraseña" />
      {error && <p role="alert">{error}</p>}
      <button type="submit">Entrar</button>
    </form>
  );
}
