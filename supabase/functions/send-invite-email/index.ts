// Send group invite email via Resend. Called by app after creating group_invites row.
// Expects body: { invite_id: string }. Uses RESEND_API_KEY and optional FROM_EMAIL env.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API = "https://api.resend.com/emails";

interface InvitePayload {
  invite_id: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(), status: 204 });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization" }, 401);
    }

    const { invite_id }: InvitePayload = await req.json().catch(() => ({}));
    if (!invite_id || typeof invite_id !== "string") {
      return json({ error: "Missing invite_id" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: invite, error: inviteError } = await supabase
      .from("group_invites")
      .select("group_id, invited_email, groups(name, invite_code)")
      .eq("id", invite_id)
      .eq("status", "pending")
      .single();

    if (inviteError || !invite) {
      console.error("[send-invite-email] invite fetch failed:", inviteError);
      return json({ error: "Invite not found or not pending" }, 404);
    }

    const groups = invite.groups as { name?: string; invite_code?: string } | null;
    const groupName = groups?.name ?? "a group";
    const inviteCode = groups?.invite_code ?? "";
    const toEmail = invite.invited_email as string;

    const resendKey = Deno.env.get("RESEND_API_KEY");
    if (!resendKey) {
      console.error("[send-invite-email] RESEND_API_KEY not set");
      return json({ error: "Email service not configured" }, 500);
    }

    const fromEmail = Deno.env.get("FROM_EMAIL") ?? "Got Motion <onboarding@resend.dev>";
    const subject = `You're invited to join ${groupName} on Got Motion`;
    const body = `
<p>You've been invited to join <strong>${escapeHtml(groupName)}</strong> on Got Motion.</p>
<p><strong>Invite code:</strong> <code>${escapeHtml(inviteCode)}</code></p>
<p>Open the Got Motion app and use "Join with invite code" to enter this code and join the group.</p>
<p>— Got Motion</p>
`.trim();

    const res = await fetch(RESEND_API, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${resendKey}`,
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [toEmail],
        subject,
        html: body,
      }),
    });

    const resBody = await res.text();
    if (!res.ok) {
      console.error("[send-invite-email] Resend error:", res.status, resBody);
      return json(
        { error: "Failed to send email", detail: resBody.slice(0, 200) },
        502
      );
    }

    return json({ ok: true, message_id: JSON.parse(resBody || "{}").id });
  } catch (e) {
    console.error("[send-invite-email] error:", e);
    return json({ error: "Internal error" }, 500);
  }
});

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function json(body: object, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type",
  };
}
