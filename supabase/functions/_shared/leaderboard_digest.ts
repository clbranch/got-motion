/**
 * Leaderboard digests — one push per user covering groups where they're top 3.
 * Replaces "get moving" morning/evening spam.
 *
 * Schedule the same windows as before (e.g. ~8am ET and ~6pm ET).
 * At most one digest per user per calendar day (America/New_York).
 */

import { formatSteps, pick } from "./motion_copy.ts";
import {
  deliverToUser,
  serviceClient,
  todayDateString,
} from "./push.ts";

type MetricKey = "steps" | "calories" | "exercise" | "miles";

type RankLine = {
  groupId: string;
  groupName: string;
  rank: number;
  metric: MetricKey;
  yourValue: number;
  leaderValue: number;
};

type Totals = {
  steps: number;
  calories: number;
  exercise: number;
  miles: number;
};

function metricLabel(metric: MetricKey): string {
  switch (metric) {
    case "calories":
      return "calories";
    case "exercise":
      return "exercise minutes";
    case "miles":
      return "miles";
    default:
      return "steps";
  }
}

function formatMetric(metric: MetricKey, value: number): string {
  if (metric === "miles") return `${value.toFixed(1)} mi`;
  if (metric === "calories") return `${formatSteps(Math.round(value))} cal`;
  if (metric === "exercise") return `${Math.round(value)} min`;
  return `${formatSteps(Math.round(value))} steps`;
}

function gapCopy(line: RankLine): string {
  const gap = Math.max(0, line.leaderValue - line.yourValue);
  const group = line.groupName;
  if (line.rank === 1) {
    return pick(
      [
        `Leading ${metricLabel(line.metric)} in ${group} — keep it.`,
        `You're #1 in ${metricLabel(line.metric)} in ${group}. Hold the lead.`,
      ],
      line.rank + Math.round(line.yourValue),
    );
  }
  if (gap <= 0) {
    return `#${line.rank} in ${metricLabel(line.metric)} in ${group}.`;
  }
  return pick(
    [
      `#${line.rank} in ${group} — ${formatMetric(line.metric, gap)} from 1st. Let's go.`,
      `You're #${line.rank} in ${group}. Need ${formatMetric(line.metric, gap)} to take the lead.`,
    ],
    line.rank * 17 + Math.round(gap),
  );
}

function buildDigestBody(lines: RankLine[]): string {
  if (lines.length === 1) return gapCopy(lines[0]!);
  return lines.map((line) => gapCopy(line)).join(" · ");
}

function buildDigestTitle(lines: RankLine[]): string {
  if (lines.length === 1) {
    return lines[0]!.groupName.trim() || "Leaderboard";
  }
  return "Your standings";
}

function valueFor(totals: Totals | undefined, metric: MetricKey): number {
  if (!totals) return 0;
  switch (metric) {
    case "calories":
      return totals.calories;
    case "exercise":
      return totals.exercise;
    case "miles":
      return totals.miles;
    default:
      return totals.steps;
  }
}

/** Shared entry used by morning / evening / group cron schedules. */
export async function sendTopThreeDigests(): Promise<{
  ok: true;
  date: string;
  candidates: number;
  sent: number;
  skipped: number;
  apns: number;
}> {
  const supabase = serviceClient();
  const today = todayDateString();

  const { data: allMembers, error: allMemError } = await supabase
    .from("group_members")
    .select("group_id, user_id");
  if (allMemError) throw allMemError;
  if (!allMembers || allMembers.length === 0) {
    return { ok: true, date: today, candidates: 0, sent: 0, skipped: 0, apns: 0 };
  }

  const groupIds = [...new Set(allMembers.map((m) => m.group_id as string))];
  const { data: groups } = await supabase
    .from("groups")
    .select("id, name")
    .in("id", groupIds);
  const groupNameById = new Map(
    (groups ?? []).map((g) => [g.id as string, (g.name as string) ?? "Group"]),
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
    .select("user_id, steps, active_calories, exercise_minutes, miles")
    .eq("date", today)
    .in("user_id", allUserIds);
  if (stepsError) throw stepsError;

  const totalsByUser = new Map<string, Totals>();
  for (const row of stepRows ?? []) {
    totalsByUser.set(row.user_id as string, {
      steps: (row.steps as number) ?? 0,
      calories: (row.active_calories as number) ?? 0,
      exercise: (row.exercise_minutes as number) ?? 0,
      miles: Number(row.miles ?? 0),
    });
  }

  const linesByUser = new Map<string, RankLine[]>();

  for (const [groupId, memberIds] of membersByGroup) {
    if (memberIds.length < 2) continue;
    const groupName = groupNameById.get(groupId) ?? "your group";

    // Primary: steps top 3.
    const stepsBoard = memberIds
      .map((userId) => ({
        userId,
        value: valueFor(totalsByUser.get(userId), "steps"),
      }))
      .sort((a, b) => b.value - a.value);
    const leaderSteps = stepsBoard[0]?.value ?? 0;

    for (let i = 0; i < Math.min(3, stepsBoard.length); i++) {
      const { userId, value } = stepsBoard[i]!;
      const list = linesByUser.get(userId) ?? [];
      list.push({
        groupId,
        groupName,
        rank: i + 1,
        metric: "steps",
        yourValue: value,
        leaderValue: leaderSteps,
      });
      linesByUser.set(userId, list);
    }

    // Also mention leading calories / exercise / miles if that leader isn't
    // already covered by steps top 3 for this group.
    for (const metric of ["calories", "exercise", "miles"] as MetricKey[]) {
      const board = memberIds
        .map((userId) => ({
          userId,
          value: valueFor(totalsByUser.get(userId), metric),
        }))
        .sort((a, b) => b.value - a.value);
      const leader = board[0];
      if (!leader || leader.value <= 0) continue;
      const already = (linesByUser.get(leader.userId) ?? []).some(
        (l) => l.groupId === groupId,
      );
      if (already) continue;
      const list = linesByUser.get(leader.userId) ?? [];
      list.push({
        groupId,
        groupName,
        rank: 1,
        metric,
        yourValue: leader.value,
        leaderValue: leader.value,
      });
      linesByUser.set(leader.userId, list);
    }
  }

  let sent = 0;
  let skipped = 0;
  let apns = 0;

  for (const [userId, lines] of linesByUser) {
    const { data: pref } = await supabase
      .from("notification_preferences")
      .select("push_enabled, group_activity, rank_changes")
      .eq("user_id", userId)
      .maybeSingle();

    if (
      pref &&
      (!pref.push_enabled ||
        (pref.group_activity === false && pref.rank_changes === false))
    ) {
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

    const capped = lines.slice(0, 4);
    const result = await deliverToUser(supabase, {
      userId,
      title: buildDigestTitle(capped),
      body: buildDigestBody(capped),
      type: "group_activity",
      data: {
        kind: "leaderboard_digest",
        groups: capped.map((l) => ({
          group_id: l.groupId,
          group_name: l.groupName,
          rank: l.rank,
          metric: l.metric,
          your_value: l.yourValue,
          leader_value: l.leaderValue,
        })),
        source: "push-leaderboard-digest",
      },
    });
    sent += 1;
    apns += result.sent;
  }

  return {
    ok: true,
    date: today,
    candidates: linesByUser.size,
    sent,
    skipped,
    apns,
  };
}
