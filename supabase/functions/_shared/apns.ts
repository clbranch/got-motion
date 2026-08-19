/**
 * APNs HTTP/2 helper for Got Motion Edge Functions.
 * Secrets (never in the mobile app):
 *   APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY,
 *   APNS_PRODUCTION ("true" for App Store / TestFlight production APNs)
 */

import * as jose from "https://esm.sh/jose@5.9.6";

export type ApnsPayload = {
  title: string;
  body: string;
  data?: Record<string, unknown>;
};

let cachedJwt: { token: string; exp: number } | null = null;

export function apnsConfigured(): boolean {
  return Boolean(
    Deno.env.get("APNS_KEY_ID") &&
      Deno.env.get("APNS_TEAM_ID") &&
      Deno.env.get("APNS_BUNDLE_ID") &&
      Deno.env.get("APNS_PRIVATE_KEY"),
  );
}

function host(): string {
  const prod = (Deno.env.get("APNS_PRODUCTION") ?? "false").toLowerCase();
  return prod === "true" || prod === "1"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

function normalizePrivateKey(raw: string): string {
  // Supabase secrets often store newlines as \n
  let key = raw.trim();
  if (key.includes("\\n")) key = key.replace(/\\n/g, "\n");
  if (!key.includes("BEGIN PRIVATE KEY")) {
    key = `-----BEGIN PRIVATE KEY-----\n${key}\n-----END PRIVATE KEY-----`;
  }
  return key;
}

async function getProviderToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.exp - 60 > now) return cachedJwt.token;

  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const privateKeyPem = normalizePrivateKey(Deno.env.get("APNS_PRIVATE_KEY")!);
  const privateKey = await jose.importPKCS8(privateKeyPem, "ES256");

  const exp = now + 50 * 60;
  const token = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .setExpirationTime(exp)
    .sign(privateKey);

  cachedJwt = { token, exp };
  return token;
}

export async function sendApns(
  deviceToken: string,
  payload: ApnsPayload,
): Promise<{ ok: boolean; status: number; body: string }> {
  if (!apnsConfigured()) {
    return { ok: false, status: 500, body: "APNs secrets not configured" };
  }

  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
  const jwt = await getProviderToken();
  const url = `${host()}/3/device/${deviceToken}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: payload.title,
          body: payload.body,
        },
        sound: "default",
      },
      ...(payload.data ?? {}),
    }),
  });

  const body = await res.text();
  return { ok: res.status === 200, status: res.status, body };
}
