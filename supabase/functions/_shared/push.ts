import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { apnsConfigured, sendApns } from "./apns.ts";

export function json(body: object, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, content-type, x-cron-secret",
    },
  });
}

export function corsPreflight() {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, content-type, x-cron-secret",
    },
  });
}

/** Service-role client (bypasses RLS). Only use inside Edge Functions. */
export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  return createClient(url, key);
}

/** True if request is cron/admin (service role bearer or matching CRON_SECRET). */
export function isAuthorizedCron(req: Request): boolean {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const headerSecret = req.headers.get("x-cron-secret");
  if (cronSecret && headerSecret && headerSecret === cronSecret) return true;

  const auth = req.headers.get("Authorization") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (serviceKey && auth === `Bearer ${serviceKey}`) return true;
  return false;
}

export async function requireUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization");
  if (!auth) return null;
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: auth } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}

export type PushTarget = {
  userId: string;
  token: string;
};

export async function loadEnabledIosTokens(
  supabase: SupabaseClient,
  userIds?: string[],
): Promise<PushTarget[]> {
  let query = supabase
    .from("push_devices")
    .select("user_id, token")
    .eq("platform", "ios")
    .eq("enabled", true);

  if (userIds && userIds.length > 0) {
    query = query.in("user_id", userIds);
  }

  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []).map((row) => ({
    userId: row.user_id as string,
    token: row.token as string,
  }));
}

export async function insertInboxNotification(
  supabase: SupabaseClient,
  row: {
    userId: string;
    groupId?: string | null;
    type: string;
    title: string;
    body: string;
    data?: Record<string, unknown>;
  },
) {
  const { error } = await supabase.from("notifications").insert({
    user_id: row.userId,
    group_id: row.groupId ?? null,
    type: row.type,
    title: row.title,
    body: row.body,
    data: row.data ?? {},
  });
  if (error) console.error("[push] inbox insert failed:", error);
}

export async function deliverToUser(
  supabase: SupabaseClient,
  opts: {
    userId: string;
    title: string;
    body: string;
    type: string;
    groupId?: string | null;
    data?: Record<string, unknown>;
  },
): Promise<{ sent: number; failed: number; skippedReason?: string }> {
  if (!apnsConfigured()) {
    return { sent: 0, failed: 0, skippedReason: "apns_not_configured" };
  }

  const tokens = await loadEnabledIosTokens(supabase, [opts.userId]);
  if (tokens.length === 0) {
    // Still write inbox so Notification Center stays useful.
    await insertInboxNotification(supabase, {
      userId: opts.userId,
      groupId: opts.groupId,
      type: opts.type,
      title: opts.title,
      body: opts.body,
      data: opts.data,
    });
    return { sent: 0, failed: 0, skippedReason: "no_device_token" };
  }

  let sent = 0;
  let failed = 0;
  for (const t of tokens) {
    const result = await sendApns(t.token, {
      title: opts.title,
      body: opts.body,
      data: {
        type: opts.type,
        ...(opts.groupId ? { group_id: opts.groupId } : {}),
        ...(opts.data ?? {}),
      },
    });
    if (result.ok) sent += 1;
    else {
      failed += 1;
      console.error("[push] APNs failed", result.status, result.body);
      // Disable bad tokens (Unregistered / BadDeviceToken)
      if (result.status === 410 || result.body.includes("BadDeviceToken")) {
        await supabase
          .from("push_devices")
          .update({ enabled: false })
          .eq("user_id", t.userId)
          .eq("token", t.token);
      }
    }
  }

  await insertInboxNotification(supabase, {
    userId: opts.userId,
    groupId: opts.groupId,
    type: opts.type,
    title: opts.title,
    body: opts.body,
    data: opts.data,
  });

  return { sent, failed };
}

export function todayDateString(timeZone = "America/New_York"): string {
  // YYYY-MM-DD in the product timezone (adjust later per-user if needed)
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}
