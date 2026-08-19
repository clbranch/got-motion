/**
 * Group rank nudges — personalized to where each member sits today.
 *
 * Schedule sparsely — at most 1–2 times per day (e.g. late morning + late
 * afternoon). Do NOT run hourly; that gets notifications turned off.
 *
 * Logic:
 * - Build today's step leaderboard per group
 * - Notify each member with copy based on rank (1st / 2nd / last / middle)
 * - Respect push_enabled + group_activity preferences
 * - At most one group_activity nudge per recipient per day
 */

import {
  groupRankBody,
  groupRankTier,
  groupRankTitle,
} from "../_shared/motion_copy.ts";
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

    const { data: allMembers, error: allMemError } = await supabase
      .from("group_members")
      .select("group_id, user_id");

    if (allMemError) throw allMemError;
    if (!allMembers || allMembers.length === 0) {
      return json({ ok: true, date: today, notified: 0, reason: "no_groups" });
    }

    const groupIds = [...new Set(allMembers.map((m) => m.group_id as string))];

    const { data: groups } = await supabase
      .from("groups")
      .select("id, name")
      .in("id", groupIds);
    const groupNameById = new Map(
      (groups ?? []).map((g) => [g.id as string, g.name as string]),
    );

    const membersByGroup = new Map<string, string[]>();
    for (const m of allMembers) {
      const gid = m.group_id as string;
      const uid = m.user_id as string;
      const list = membersByGroup.get(gid) ?? [];
      list.push(uid);
      membersByGroup.set(gid, list);
    }

    const allUserIds = [...new Set(allMembers.map((m) => m.user_id as string))];
    const { data: stepRows, error: stepsError } = await supabase
      .from("daily_steps")
      .select("user_id, steps")
      .eq("date", today)
      .in("user_id", allUserIds);

    if (stepsError) throw stepsError;

    const stepsByUser = new Map<string, number>();
    for (const row of stepRows ?? []) {
      stepsByUser.set(row.user_id as string, (row.steps as number) ?? 0);
    }

    const notified = new Set<string>();
    let deliveries = 0;
    let skipped = 0;

    for (const [groupId, memberIds] of membersByGroup) {
      if (memberIds.length === 0) continue;

      const groupName = groupNameById.get(groupId) ?? "your group";
      const leaderboard = memberIds
        .map((userId) => ({
          userId,
          steps: stepsByUser.get(userId) ?? 0,
        }))
        .sort((a, b) => b.steps - a.steps);

      const leaderSteps = leaderboard[0]?.steps ?? 0;
      const memberCount = leaderboard.length;

      for (let i = 0; i < leaderboard.length; i++) {
        const { userId, steps } = leaderboard[i]!;
        const rank = i + 1;

        if (notified.has(userId)) continue;

        const { data: pref } = await supabase
          .from("notification_preferences")
          .select("push_enabled, group_activity")
          .eq("user_id", userId)
          .maybeSingle();

        if (pref && (!pref.push_enabled || pref.group_activity === false)) {
          skipped += 1;
          continue;
        }

        const { data: already } = await supabase
          .from("notifications")
          .select("id")
          .eq("user_id", userId)
          .eq("type", "group_activity")
          .gte("created_at", `${today}T00:00:00-04:00`)
          .limit(1);

        if (already && already.length > 0) {
          skipped += 1;
          continue;
        }

        const tier = groupRankTier(rank, memberCount);
        const body = groupRankBody({
          tier,
          groupName,
          rank,
          memberCount,
          yourSteps: steps,
          leaderSteps,
          seed: daySeed + userId.charCodeAt(0) + rank * 13,
        });

        const result = await deliverToUser(supabase, {
          userId,
          groupId,
          title: groupRankTitle(groupName),
          body,
          type: "group_activity",
          data: {
            kind: "group_rank",
            rank,
            member_count: memberCount,
            your_steps: steps,
            leader_steps: leaderSteps,
            group_name: groupName,
            tier,
            source: "push-group-motion",
          },
        });

        notified.add(userId);
        deliveries += result.sent;
      }
    }

    return json({
      ok: true,
      date: today,
      groups: membersByGroup.size,
      notified: notified.size,
      skipped,
      apns_deliveries: deliveries,
    });
  } catch (e) {
    console.error("[push-group-motion]", e);
    return json({ error: "Internal error", detail: String(e) }, 500);
  }
});
