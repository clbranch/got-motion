/**
 * Deletes workout proof photos/videos older than RETENTION_DAYS.
 * Keeps logged_workouts rows (duration, title, time) — only clears proof URLs.
 *
 * Schedule daily (Supabase Cron or external):
 *   POST .../functions/v1/cleanup-workout-proofs
 *   x-cron-secret: <CRON_SECRET>
 */

import {
  corsPreflight,
  isAuthorizedCron,
  json,
  serviceClient,
} from "../_shared/push.ts";

const RETENTION_DAYS = 7;
const BUCKET = "workout-proofs";

function storagePathFromPublicUrl(url: string | null): string | null {
  if (!url) return null;
  const marker = `/object/public/${BUCKET}/`;
  const idx = url.indexOf(marker);
  if (idx < 0) return null;
  const rest = url.slice(idx + marker.length);
  const path = rest.split("?")[0];
  return path.length > 0 ? decodeURIComponent(path) : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return corsPreflight();
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  if (!isAuthorizedCron(req)) {
    return json({ error: "Unauthorized cron" }, 401);
  }

  try {
    const supabase = serviceClient();
    const cutoff = new Date();
    cutoff.setUTCDate(cutoff.getUTCDate() - RETENTION_DAYS);
    const cutoffIso = cutoff.toISOString();

    const { data: rows, error: fetchError } = await supabase
      .from("logged_workouts")
      .select("id, proof_image_url, proof_video_url")
      .lt("created_at", cutoffIso)
      .or("proof_image_url.not.is.null,proof_video_url.not.is.null");

    if (fetchError) {
      console.error("[cleanup-workout-proofs] fetch", fetchError);
      return json({ error: fetchError.message }, 500);
    }

    const paths = new Set<string>();
    const ids: string[] = [];

    for (const row of rows ?? []) {
      const imagePath = storagePathFromPublicUrl(row.proof_image_url);
      const videoPath = storagePathFromPublicUrl(row.proof_video_url);
      if (imagePath) paths.add(imagePath);
      if (videoPath) paths.add(videoPath);
      ids.push(row.id);
    }

    let removedFiles = 0;
    const pathList = [...paths];
    if (pathList.length > 0) {
      const { error: removeError } = await supabase.storage
        .from(BUCKET)
        .remove(pathList);
      if (removeError) {
        console.error("[cleanup-workout-proofs] storage remove", removeError);
      } else {
        removedFiles = pathList.length;
      }
    }

    let clearedRows = 0;
    if (ids.length > 0) {
      const { error: updateError } = await supabase
        .from("logged_workouts")
        .update({ proof_image_url: null, proof_video_url: null })
        .in("id", ids);
      if (updateError) {
        console.error("[cleanup-workout-proofs] update", updateError);
        return json({ error: updateError.message }, 500);
      }
      clearedRows = ids.length;
    }

    return json({
      ok: true,
      retention_days: RETENTION_DAYS,
      cutoff: cutoffIso,
      storage_files_removed: removedFiles,
      rows_cleared: clearedRows,
    });
  } catch (e) {
    console.error("[cleanup-workout-proofs]", e);
    return json({ error: "Internal error" }, 500);
  }
});
