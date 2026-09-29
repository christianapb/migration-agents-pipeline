import axios from "axios";

const IDENTITY_URL = process.env.IDENTITY_URL ?? "http://identity.internal";

export interface Credentials {
  email: string;
  password: string;
}

export async function verifyCredentials(creds: Credentials): Promise<{ userId: string } | null> {
  const res = await axios.post(`${IDENTITY_URL}/verify`, creds, { validateStatus: () => true });
  if (res.status === 200) return { userId: res.data.id };
  return null;
}
