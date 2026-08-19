/**
 * Evening catch-up nudges (workout window — not spammy hourly).
 * Schedule once daily ~6pm Eastern (22:00 UTC).
 *
 * Uses catch-up motion copy. Respects push_enabled + catch_up_reminders.
 * At most one evening catch-up per user per day.
 */

import { catchUpLines, pick } from "../_shared/motion_copy.ts";
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
      .eq("push_enabled", true)
      .eq("catch_up_reminders", true);

    if (prefsError) throw prefsError;

    const userIds = (prefs ?? []).map((p) => p.user_id as string);
    let sentUsers = 0;
    let skipped = 0;
    let apnsSent = 0;

    for (const userId of userIds) {
      // Don't double-tap if they already got a catch-up today.
      const { data: existing } = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", userId)
        .eq("type", "catch_up")
        .gte("created_at", `${today}T00:00:00-04:00`)
        .limit(1);

      if (existing && existing.length > 0) {
        skipped += 1;
        continue;
      }

      const body = pick(catchUpLines, daySeed + userId.charCodeAt(0) + 17);
      const result = await deliverToUser(supabase, {
        userId,
        title: "Evening motion",
        body,
        type: "catch_up",
        data: { kind: "evening", source: "push-evening" },
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
    console.error("[push-evening]", e);
    return json({ error: "Internal error", detail: String(e) }, 500);
  }
});
