/**
 * Monday weekly award pushes — last completed Mon–Sun week.
 *
 * Schedule: `0 12 * * 1` UTC ≈ 8am Eastern on Monday.
 * Header: x-cron-secret or service-role bearer.
 *
 * Winners get their award copy. Everyone else in the group gets a recap
 * that points them to the Group tab. One weekly_award per user per week.
 *
 * Body `{ "force": true }` skips the Monday-only guard (testing).
 */

import {
  groupWeeklyRecapBody,
  groupWeeklyRecapTitle,
  weeklyAwardPushBody,
  weeklyAwardPushTitle,
  type WeeklyAwardCategoryKey,
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

type Category = "steps" | "calories" | "exercise" | "miles";

type Winner = {
  userId: string;
  displayName: string;
  category: Category;
  value: number;
};

function addDays(ymd: string, days: number): string {
  const [year, month, day] = ymd.split("-").map(Number);
  const dt = new Date(Date.UTC(year!, month! - 1, day! + days));
  return dt.toISOString().slice(0, 10);
}

function isoWeekdayMon1(ymd: string): number {
  const [year, month, day] = ymd.split("-").map(Number);
  const js = new Date(Date.UTC(year!, month! - 1, day!)).getUTCDay();
  return js === 0 ? 7 : js;
}

function lastCompletedWeek(todayYmd: string): { start: string; end: string; weekKey: string } {
  const dow = isoWeekdayMon1(todayYmd);
  const thisMonday = addDays(todayYmd, -(dow - 1));
  const start = addDays(thisMonday, -7);
  const end = addDays(thisMonday, -1);
  return { start, end, weekKey: start };
}

function pickWinner(
  totals: Map<string, { steps: number; calories: number; exercise: number; miles: number }>,
  memberIds: string[],
  read: (row: { steps: number; calories: number; exercise: number; miles: number }) => number,
): { userId: string; value: number } | null {
  let bestId: string | null = null;
  let bestValue = 0;
  for (const userId of memberIds) {
    const row = totals.get(userId);
    if (!row) continue;
    const value = read(row);
    if (value <= 0) continue;
    if (
      value > bestValue ||
      (value === bestValue && bestId != null && userId < bestId)
    ) {
      bestValue = value;
      bestId = userId;
    }
  }
  if (bestId == null) return null;
  return { userId: bestId, value: bestValue };
}

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
    const body = await req.json().catch(() => ({})) as { force?: boolean };
    const today = todayDateString();
    const isMonday = isoWeekdayMon1(today) === 1;
    if (!isMonday && !body.force) {
      return json({
        ok: true,
        date: today,
        skipped: true,
        reason: "not_monday",
      });
    }

    const week = lastCompletedWeek(today);
    const supabase = serviceClient();

    const { data: allMembers, error: memError } = await supabase
      .from("group_members")
      .select("group_id, user_id");
    if (memError) throw memError;
    if (!allMembers || allMembers.length === 0) {
      return json({ ok: true, date: today, week, notified: 0, reason: "no_groups" });
    }

    const groupIds = [...new Set(allMembers.map((m) => m.group_id as string))];
    const { data: groups } = await supabase
      .from("groups")
      .select("id, name")
      .in("id", groupIds);
    const groupNameById = new Map(
      (groups ?? []).map((g) => [g.id as string, (g.name as string) || "your group"]),
    );

    const membersByGroup = new Map<string, string[]>();
    for (const row of allMembers) {
      const gid = row.group_id as string;
      const uid = row.user_id as string;
      const list = membersByGroup.get(gid) ?? [];
      list.push(uid);
      membersByGroup.set(gid, list);
    }

    const allUserIds = [...new Set(allMembers.map((m) => m.user_id as string))];
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, display_name, full_name")
      .in("id", allUserIds);
    const nameByUser = new Map<string, string>();
    for (const p of profiles ?? []) {
      const name =
        (p.display_name as string | null)?.trim() ||
        (p.full_name as string | null)?.trim() ||
        "A teammate";
      nameByUser.set(p.id as string, name);
    }

    const { data: stepRows, error: stepsError } = await supabase
      .from("daily_steps")
      .select("user_id, steps, miles, active_calories, exercise_minutes")
      .gte("date", week.start)
      .lte("date", week.end)
      .in("user_id", allUserIds);
    if (stepsError) throw stepsError;

    const totals = new Map<
      string,
      { steps: number; calories: number; exercise: number; miles: number }
    >();
    for (const uid of allUserIds) {
      totals.set(uid, { steps: 0, calories: 0, exercise: 0, miles: 0 });
    }
    for (const row of stepRows ?? []) {
      const uid = row.user_id as string;
      const current = totals.get(uid);
      if (!current) continue;
      current.steps += (row.steps as number) ?? 0;
      current.calories += (row.active_calories as number) ?? 0;
      current.exercise += (row.exercise_minutes as number) ?? 0;
      current.miles += (row.miles as number) ?? 0;
    }

    const notified = new Set<string>();
    let winnerPushes = 0;
    let recapPushes = 0;
    let apnsSent = 0;
    let skippedPrefs = 0;

    for (const [groupId, memberIds] of membersByGroup) {
      const groupName = groupNameById.get(groupId) ?? "your group";
      const winners: Winner[] = [];

      const add = (category: Category, picked: { userId: string; value: number } | null) => {
        if (!picked) return;
        winners.push({
          userId: picked.userId,
          displayName: nameByUser.get(picked.userId) ?? "A teammate",
          category,
          value: picked.value,
        });
      };

      add("steps", pickWinner(totals, memberIds, (r) => r.steps));
      add("calories", pickWinner(totals, memberIds, (r) => r.calories));
      add("exercise", pickWinner(totals, memberIds, (r) => r.exercise));
      add("miles", pickWinner(totals, memberIds, (r) => r.miles));

      if (winners.length === 0) continue;

      for (const userId of memberIds) {
        if (notified.has(userId)) continue;

        const { data: pref } = await supabase
          .from("notification_preferences")
          .select("push_enabled, weekly_recap")
          .eq("user_id", userId)
          .maybeSingle();
        if (pref && (pref.push_enabled === false || pref.weekly_recap === false)) {
          skippedPrefs += 1;
          continue;
        }

        const { data: already } = await supabase
          .from("notifications")
          .select("id")
          .eq("user_id", userId)
          .eq("type", "weekly_award")
          .gte("created_at", `${week.end}T00:00:00-04:00`)
          .limit(1);
        if (already && already.length > 0) {
          notified.add(userId);
          continue;
        }

        const mine = winners.filter((w) => w.userId === userId);
        const title = mine.length > 0
          ? weeklyAwardPushTitle(mine.map((w) => w.category as WeeklyAwardCategoryKey))
          : groupWeeklyRecapTitle(groupName);
        const text = mine.length > 0
          ? weeklyAwardPushBody({
            groupName,
            categories: mine.map((w) => ({ category: w.category, value: w.value })),
          })
          : groupWeeklyRecapBody({ groupName, winners });

        const result = await deliverToUser(supabase, {
          userId,
          groupId,
          title,
          body: text,
          type: "weekly_award",
          data: {
            kind: mine.length > 0 ? "weekly_award_winner" : "weekly_award_recap",
            screen: "group",
            group_id: groupId,
            group_name: groupName,
            week_key: week.weekKey,
            week_start: week.start,
            week_end: week.end,
            source: "push-weekly-awards",
          },
        });

        notified.add(userId);
        apnsSent += result.sent;
        if (mine.length > 0) winnerPushes += 1;
        else recapPushes += 1;
      }
    }

    return json({
      ok: true,
      date: today,
      week,
      notified: notified.size,
      winner_pushes: winnerPushes,
      recap_pushes: recapPushes,
      skipped_prefs: skippedPrefs,
      apns_deliveries: apnsSent,
    });
  } catch (e) {
    console.error("[push-weekly-awards]", e);
    return json({ error: "Internal error", detail: String(e) }, 500);
  }
});
