/**
 * Notify group mates when someone finishes a Got Motion workout (with optional proof).
 *
 * Auth: signed-in user who owns the workout.
 * Body: { "workout_id": "<uuid>" }
 */

import {
  corsPreflight,
  deliverToUser,
  json,
  requireUserId,
  serviceClient,
} from "../_shared/push.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return corsPreflight();
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  try {
    const userId = await requireUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => ({})) as {
      workout_id?: string;
    };
    const workoutId = body.workout_id?.trim();
    if (!workoutId) return json({ error: "workout_id required" }, 400);

    const supabase = serviceClient();
    const { data: workout, error: workoutErr } = await supabase
      .from("logged_workouts")
      .select(
        "id, user_id, group_id, title, duration_seconds, proof_image_url, proof_video_url",
      )
      .eq("id", workoutId)
      .maybeSingle();

    if (workoutErr) throw workoutErr;
    if (!workout) return json({ error: "Workout not found" }, 404);
    if (workout.user_id !== userId) return json({ error: "Forbidden" }, 403);
    if (!workout.group_id) {
      return json({ ok: true, notified: 0, reason: "no_group" });
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("display_name, full_name")
      .eq("id", userId)
      .maybeSingle();

    const name =
      (profile?.display_name as string | undefined)?.trim() ||
      (profile?.full_name as string | undefined)?.trim() ||
      "Someone";

    const minutes = Math.max(
      1,
      Math.round(Number(workout.duration_seconds) / 60),
    );
    const title = `${name} logged a workout`;
    const hasProof = !!(workout.proof_image_url || workout.proof_video_url);
    const text = hasProof
      ? `${minutes} min ${workout.title} — proof attached`
      : `${minutes} min ${workout.title}`;

    const { data: members, error: membersErr } = await supabase
      .from("group_members")
      .select("user_id")
      .eq("group_id", workout.group_id);

    if (membersErr) throw membersErr;

    const recipientIds = (members ?? [])
      .map((m) => m.user_id as string)
      .filter((id) => id !== userId);

    let notified = 0;
    for (const recipientId of recipientIds) {
      const { data: pref } = await supabase
        .from("notification_preferences")
        .select("push_enabled, group_activity")
        .eq("user_id", recipientId)
        .maybeSingle();

      // Always write inbox; only skip push if prefs say so (deliverToUser still
      // inserts inbox). Prefer group_activity for workout social proof.
      if (pref && pref.group_activity === false) {
        continue;
      }

      await deliverToUser(supabase, {
        userId: recipientId,
        groupId: workout.group_id,
        type: "workout_logged",
        title,
        body: text,
        data: {
          screen: "workout",
          workout_id: workout.id,
          proof_image_url: workout.proof_image_url,
          proof_video_url: workout.proof_video_url,
        },
      });
      notified += 1;
    }

    return json({ ok: true, notified });
  } catch (e) {
    console.error("[notify-workout-logged]", e);
    return json({ error: String(e) }, 500);
  }
});
