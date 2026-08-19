/**
 * Group “someone already moving” nudges.
 *
 * Schedule sparsely — at most 1–2 times per day (e.g. late morning + late
 * afternoon). Do NOT run hourly; that gets notifications turned off.
 *
 * Logic:
 * - Find users with daily_steps.steps >= threshold today
 * - Notify other members of their groups (leaderboard-visible facts only)
 * - Respect push_enabled + group_activity preferences
 * - At most one group_activity / leader_update nudge per recipient per day
 */

import { someoneMovingLine } from "../_shared/motion_copy.ts";
import {
  corsPreflight,
  deliverToUser,
  isAuthorizedCron,
  json,
  serviceClient,
  todayDateString,
} from "../_shared/push.ts";
import { apnsConfigured } from "../_shared/apns.ts";

const STEPS_THRESHOLD = 200;

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

    const { data: movers, error: moversError } = await supabase
      .from("daily_steps")
      .select("user_id, steps")
      .eq("date", today)
      .gte("steps", STEPS_THRESHOLD);

    if (moversError) throw moversError;
    if (!movers || movers.length === 0) {
      return json({ ok: true, date: today, notified: 0, reason: "no_movers" });
    }

    const moverIds = movers.map((m) => m.user_id as string);
    const stepsByUser = new Map(
      movers.map((m) => [m.user_id as string, m.steps as number]),
    );

    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, display_name, full_name")
      .in("id", moverIds);

    const nameByUser = new Map<string, string>();
    for (const p of profiles ?? []) {
      const name =
        (p.display_name as string | null)?.trim() ||
        (p.full_name as string | null)?.trim() ||
        "A teammate";
      nameByUser.set(p.id as string, name);
    }

    const { data: memberships, error: memError } = await supabase
      .from("group_members")
      .select("group_id, user_id")
      .in("user_id", moverIds);

    if (memError) throw memError;

    const groupIds = [
      ...new Set((memberships ?? []).map((m) => m.group_id as string)),
    ];
    if (groupIds.length === 0) {
      return json({ ok: true, date: today, notified: 0, reason: "no_groups" });
    }

    const { data: groups } = await supabase
      .from("groups")
      .select("id, name")
      .in("id", groupIds);
    const groupNameById = new Map(
      (groups ?? []).map((g) => [g.id as string, g.name as string]),
    );

    const { data: allMembers, error: allMemError } = await supabase
      .from("group_members")
      .select("group_id, user_id")
      .in("group_id", groupIds);

    if (allMemError) throw allMemError;

    // Pick one "featured" mover per group (highest steps).
    const featuredByGroup = new Map<string, { userId: string; steps: number }>();
    for (const m of memberships ?? []) {
      const gid = m.group_id as string;
      const uid = m.user_id as string;
      const steps = stepsByUser.get(uid) ?? 0;
      const current = featuredByGroup.get(gid);
      if (!current || steps > current.steps) {
        featuredByGroup.set(gid, { userId: uid, steps });
      }
    }

    const notified = new Set<string>();
    let deliveries = 0;

    for (const [groupId, featured] of featuredByGroup) {
      const groupName = groupNameById.get(groupId) ?? "your group";
      const moverName = nameByUser.get(featured.userId) ?? "A teammate";
      const body = someoneMovingLine({
        name: moverName,
        steps: featured.steps,
        groupName,
        seed: featured.steps + groupId.length,
      });

      const recipients = (allMembers ?? [])
        .filter((m) => m.group_id === groupId && m.user_id !== featured.userId)
        .map((m) => m.user_id as string);

      for (const recipientId of recipients) {
        if (notified.has(recipientId)) continue;

        const { data: pref } = await supabase
          .from("notification_preferences")
          .select("push_enabled, group_activity")
          .eq("user_id", recipientId)
          .maybeSingle();

        if (!pref?.push_enabled || pref.group_activity === false) continue;

        const { data: already } = await supabase
          .from("notifications")
          .select("id")
          .eq("user_id", recipientId)
          .in("type", ["leader_update", "group_activity"])
          .gte("created_at", `${today}T00:00:00-04:00`)
          .limit(1);

        if (already && already.length > 0) continue;

        const result = await deliverToUser(supabase, {
          userId: recipientId,
          groupId,
          title: "Group motion",
          body,
          type: "leader_update",
          data: {
            kind: "group_moving",
            mover_user_id: featured.userId,
            mover_name: moverName,
            steps: featured.steps,
            group_name: groupName,
            source: "push-group-motion",
          },
        });

        notified.add(recipientId);
        deliveries += result.sent;
      }
    }

    return json({
      ok: true,
      date: today,
      movers: movers.length,
      groups: featuredByGroup.size,
      notified: notified.size,
      apns_deliveries: deliveries,
    });
  } catch (e) {
    console.error("[push-group-motion]", e);
    return json({ error: "Internal error", detail: String(e) }, 500);
  }
});
