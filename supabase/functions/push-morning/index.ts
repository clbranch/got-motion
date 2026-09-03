/**
 * Morning schedule — leaderboard digests only (no "get moving" copy).
 */

import { sendTopThreeDigests } from "../_shared/leaderboard_digest.ts";
import {
  corsPreflight,
  isAuthorizedCron,
  json,
} from "../_shared/push.ts";
import { apnsConfigured } from "../_shared/apns.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return corsPreflight();
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  if (!isAuthorizedCron(req)) return json({ error: "Unauthorized cron" }, 401);
  if (!apnsConfigured()) return json({ error: "APNs not configured" }, 503);

  try {
    return json({ ...(await sendTopThreeDigests()), slot: "morning" });
  } catch (e) {
    console.error("[push-morning]", e);
    return json({ error: "Internal error", detail: String(e) }, 500);
  }
});
