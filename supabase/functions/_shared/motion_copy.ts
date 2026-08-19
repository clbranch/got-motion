/** Motion-first push copy (keep in sync with lib/services/motion_push_copy.dart). */

export const morningLines = [
  "Wake up. Find your motion.",
  "Morning motion starts now.",
  "The day’s moving. Get in motion.",
  "No motion yet? Let’s change that.",
  "Your daily motion is waiting.",
  "Start small. Stay in motion.",
  "Today needs some motion from you.",
  "Got Motion? Go make some.",
  "Your first move is the whole point.",
  "Motion check: morning edition.",
] as const;

export const catchUpLines = [
  "Everybody got motion but you.",
  "No motion detected. That can’t be you.",
  "They got motion. You got time.",
  "The motion party started without you.",
  "You can’t lead the motion from the sidelines.",
] as const;

export const groupActivityLines = [
  "The crew got motion before noon.",
  "Someone in your group is making motion happen.",
  "The leaderboard is moving. Jump in.",
  "Your group’s motion is picking up.",
  "The crew is in motion. Don’t come in late.",
] as const;

export function pick<T>(lines: readonly T[], seed?: number): T {
  if (lines.length === 0) throw new Error("empty copy list");
  const index =
    seed === undefined
      ? Math.floor(Math.random() * lines.length)
      : Math.abs(seed) % lines.length;
  return lines[index]!;
}

export function formatSteps(steps: number): string {
  return Math.abs(steps).toLocaleString("en-US");
}

export function memberStepsEarly(name: string, steps: number): string {
  return `${name} got motion early: ${formatSteps(steps)} steps already.`;
}

export function memberInMotionYourTurn(name: string): string {
  return `${name} is in motion. Your turn.`;
}

export function memberPutMotionOnBoard(name: string, steps: number): string {
  return `${name} put motion on the board: ${formatSteps(steps)} steps.`;
}

export function groupAlreadyInMotion(groupName: string): string {
  return `${groupName} is already in motion.`;
}

export function motionAlreadyOnBoard(groupName: string): string {
  return `Motion is already on the board in ${groupName}.`;
}

/** Weekly category award titles (keep in sync with lib/services/weekly_award_copy.dart). */
export const weeklyAwardTitles = {
  steps: "Big Stepper",
  calories: "Calorie King",
  exercise: "Exercise Pro",
  miles: "Distance Leader",
  sweep: "The LeBron of Motion!",
  multi: "You're stacking awards",
} as const;

export type WeeklyAwardCategoryKey = keyof typeof weeklyAwardTitles;

export function formatWeeklyValue(
  category: "steps" | "calories" | "exercise" | "miles",
  value: number,
): string {
  switch (category) {
    case "steps":
      return formatSteps(Math.round(value));
    case "calories":
      return `${Math.round(value)} cal`;
    case "exercise":
      return `${Math.round(value)} min`;
    case "miles":
      return Number.isInteger(value)
        ? `${Math.round(value)} mi`
        : `${value.toFixed(1)} mi`;
  }
}

export function weeklyAwardPushTitle(
  categories: WeeklyAwardCategoryKey[],
): string {
  const keys = categories.filter((k) => k !== "sweep" && k !== "multi");
  if (keys.length >= 4) return weeklyAwardTitles.sweep;
  if (keys.length === 1) return weeklyAwardTitles[keys[0]!];
  return weeklyAwardTitles.multi;
}

export function weeklyAwardPushBody(opts: {
  groupName: string;
  categories: Array<{
    category: "steps" | "calories" | "exercise" | "miles";
    value: number;
  }>;
}): string {
  const { groupName, categories } = opts;
  if (categories.length >= 4) {
    return `You swept steps, calories, exercise, and miles in ${groupName}. The LeBron of Motion.`;
  }
  if (categories.length === 1) {
    const { category, value } = categories[0]!;
    const formatted = formatWeeklyValue(category, value);
    switch (category) {
      case "steps":
        return `You led ${groupName} in steps — ${formatted}. Nobody else came close.`;
      case "calories":
        return `Most active calories in ${groupName} — ${formatted}. You burned it up.`;
      case "exercise":
        return `Most exercise minutes in ${groupName} — ${formatted}. You really moved that weight.`;
      case "miles":
        return `Most miles in ${groupName} — ${formatted}. You ran circles around everyone.`;
    }
  }
  const lines = categories
    .map((c) => {
      const label = weeklyAwardTitles[c.category];
      return `${label} (${formatWeeklyValue(c.category, c.value)})`;
    })
    .join(", ");
  return `You led ${groupName} in ${lines}. Keep that motion going.`;
}

export function someoneMovingLine(opts: {
  name: string;
  steps: number;
  groupName?: string;
  seed?: number;
}): string {
  const options = [
    memberStepsEarly(opts.name, opts.steps),
    memberInMotionYourTurn(opts.name),
    memberPutMotionOnBoard(opts.name, opts.steps),
    ...(opts.groupName
      ? [
        groupAlreadyInMotion(opts.groupName),
        motionAlreadyOnBoard(opts.groupName),
      ]
      : []),
    ...groupActivityLines,
  ];
  return pick(options, opts.seed);
}

export type GroupRankTier = "first" | "second" | "last" | "middle";

export function groupRankTier(rank: number, memberCount: number): GroupRankTier {
  if (rank <= 1) return "first";
  if (rank >= memberCount) return "last";
  if (rank === 2) return "second";
  return "middle";
}

export function groupRankTitle(groupName: string): string {
  const trimmed = groupName.trim();
  return trimmed.length > 0 ? trimmed : "Group motion";
}

export function groupRankBody(opts: {
  tier: GroupRankTier;
  groupName: string;
  rank: number;
  memberCount: number;
  yourSteps: number;
  leaderSteps: number;
  seed?: number;
}): string {
  const group = opts.groupName.trim() || "your group";
  const gap = Math.max(0, opts.leaderSteps - opts.yourSteps);
  const gapLabel = gap > 0 ? formatSteps(gap) : null;

  const lines: Record<GroupRankTier, string[]> = {
    first: [
      `Hey — keep up the good work. You're killing it in ${group} today.`,
      `You're setting the pace in ${group}. Keep that motion going.`,
      `Leading ${group} today — stay on it. You're killing it.`,
    ],
    second: [
      ...(gapLabel
        ? [
          `Hey — you're almost there. ${gapLabel} steps from the lead in ${group}. Get moving.`,
        ]
        : []),
      `Hey — you're right there. Push a little harder and take ${group}.`,
      `Second in ${group} today. You're almost there — get moving.`,
    ],
    last: [
      `Hey — what you doing? Looks like a day off in ${group}. Tighten up and get going.`,
      `Come on — ${group} is moving without you. Let's get going.`,
      `Last on the board in ${group} today. Shake it off and get in motion.`,
    ],
    middle: [
      `Still room to climb in ${group} — keep pushing.`,
      `#${opts.rank} in ${group} today. Pick up the pace.`,
      `You're in the mix in ${group}. Keep stacking motion.`,
    ],
  };

  const pool = lines[opts.tier];
  const seed = opts.seed ?? opts.rank + opts.memberCount + opts.yourSteps;
  return pick(pool, seed);
}
