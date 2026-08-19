/**
 * Morning motion nudges.
 * Schedule with Supabase Cron (e.g. 12:00 UTC ≈ 8am ET) and header:
 *   x-cron-secret: <CRON_SECRET>
 * or Authorization: Bearer <SERVICE_ROLE_KEY>
 *
 * Sends one morning line per opted-in user who has not already received a
 * daily_return notification today (America/New_York calendar day).
 */

import { morningLines, pick } from "../_shared/motion_copy.ts";
import {
  corsPreflight,
  deliverToUser,
  isAuthorizedCron,
  json,
  serviceClient,
  todayDateString,
} from "../_shared/push.ts";
import { apnsConfigured } from "../_shared/apns.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return corsPreflight();
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  if (!isAuthorizedCron(req)) {
    return json({ error: "Unauthorized cron" }, 401);
  }

  if (!apnsConfigured()) {
    return json({ error: "APNs not configured" }, 503);
  }

  try {
    const supabase = serviceClient();
    const today = todayDateString();
    const daySeed = Number(today.replaceAll("-", ""));

    const { data: prefs, error: prefsError } = await supabase
      .from("notification_preferences")
      .select("user_id")
      .eq("push_enabled", true);

    if (prefsError) throw prefsError;

    const userIds = (prefs ?? []).map((p) => p.user_id as string);
    let sentUsers = 0;
    let skipped = 0;
    let apnsSent = 0;

    for (const userId of userIds) {
      const { data: existing } = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", userId)
        .eq("type", "daily_return")
        .gte("created_at", `${today}T00:00:00-04:00`)
        .limit(1);

      if (existing && existing.length > 0) {
        skipped += 1;
        continue;
      }

      const body = pick(morningLines, daySeed + userId.charCodeAt(0));
      const result = await deliverToUser(supabase, {
        userId,
        title: "Morning motion",
        body,
        type: "daily_return",
        data: { kind: "morning", source: "push-morning" },
      });
      sentUsers += 1;
      apnsSent += result.sent;
    }

    return json({
      ok: true,
      date: today,
      candidates: userIds.length,
      notified: sentUsers,
      skipped_already_sent: skipped,
      apns_deliveries: apnsSent,
    });
  } catch (e) {
    console.error("[push-morning]", e);
    return json({ error: "Internal error", detail: String(e) }, 500);
  }
});
