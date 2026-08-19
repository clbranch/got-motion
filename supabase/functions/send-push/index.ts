/**
 * Manual / test push.
 *
 * Auth:
 * - Signed-in user → sends a test push to themselves
 * - Cron/service role → body.user_id required (or "me" not allowed)
 *
 * Body (optional):
 *   { "kind": "morning" | "catch_up" | "group" | "custom",
 *     "title"?: string, "body"?: string, "user_id"?: string }
 */

import {
  catchUpLines,
  morningLines,
  pick,
  someoneMovingLine,
} from "../_shared/motion_copy.ts";
import {
  corsPreflight,
  deliverToUser,
  isAuthorizedCron,
  json,
  requireUserId,
  serviceClient,
} from "../_shared/push.ts";
import { apnsConfigured } from "../_shared/apns.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return corsPreflight();
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  try {
    const body = await req.json().catch(() => ({})) as {
      kind?: string;
      title?: string;
      body?: string;
      user_id?: string;
      name?: string;
      steps?: number;
      group_name?: string;
    };

    const cron = isAuthorizedCron(req);
    let userId: string | null = null;

    if (cron && body.user_id) {
      userId = body.user_id;
    } else {
      userId = await requireUserId(req);
    }

    if (!userId) return json({ error: "Unauthorized" }, 401);

    if (!apnsConfigured()) {
      return json({
        error: "APNs not configured",
        hint:
          "Set APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY (and APNS_PRODUCTION for store builds).",
      }, 503);
    }

    const kind = body.kind ?? "morning";
    let title = body.title ?? "Got Motion";
    let text = body.body ?? "";
    let type = "daily_return";

    if (kind === "morning" || (!body.body && kind === "custom" && !text)) {
      title = "Morning motion";
      text = pick(morningLines);
      type = "daily_return";
    } else if (kind === "catch_up") {
      title = "Catch up";
      text = pick(catchUpLines);
      type = "catch_up";
    } else if (kind === "group") {
      title = "Group motion";
      text = someoneMovingLine({
        name: body.name ?? "Q",
        steps: body.steps ?? 500,
        groupName: body.group_name ?? "your group",
      });
      type = "leader_update";
    } else if (kind === "custom") {
      if (!text) return json({ error: "custom kind needs body" }, 400);
      type = "group_activity";
    }

    const supabase = serviceClient();
    const result = await deliverToUser(supabase, {
      userId,
      title,
      body: text,
      type,
      data: { kind, source: "send-push" },
    });

    return json({ ok: true, user_id: userId, title, body: text, ...result });
  } catch (e) {
    console.error("[send-push]", e);
    return json({ error: "Internal error", detail: String(e) }, 500);
  }
});
