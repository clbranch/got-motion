# Your checklist: turn on real push notifications

The app + Edge Functions are ready. You only need to finish **Apple credentials**,
**Supabase secrets**, **deploy**, and **one test**. I can’t do those from here
because they need your Apple Developer + Supabase project access.

---

## A. One-time Apple setup (you)

1. Open [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Select App ID **`com.brogrammers.gotmotionapp`**
3. Enable **Push Notifications** → Save
4. Go to [Keys](https://developer.apple.com/account/resources/authkeys/list) → **+**
5. Name it e.g. `Got Motion APNs`
6. Check **Apple Push Notifications service (APNs)** → Continue → Register
7. **Download the `.p8` file once** and note:
   - **Key ID** (10 characters)
   - **Team ID** (top-right of the Apple Developer membership page)
8. Keep the `.p8` somewhere safe (password manager / 1Password). You cannot re-download it.

---

## B. Apply the database migration (you)

In the Supabase SQL editor, run the file:

`supabase/migrations/20260818200000_notifications_foundation.sql`

Or from the repo (if linked):

```bash
cd /Users/cbranch/dev/got-motion
supabase db push
```

Confirm tables exist: `notifications`, `notification_preferences`, `push_devices`.

---

## C. Set Supabase secrets (you)

In [Supabase Dashboard → Project Settings → Edge Functions → Secrets](https://supabase.com/dashboard/project/_/settings/functions)
(or CLI below), set:

| Secret | Value |
|--------|--------|
| `APNS_KEY_ID` | Key ID from Apple |
| `APNS_TEAM_ID` | Your Apple Team ID |
| `APNS_BUNDLE_ID` | `com.brogrammers.gotmotionapp` |
| `APNS_PRIVATE_KEY` | Full contents of the `.p8` file (including `BEGIN/END` lines). If the UI won’t take newlines, paste with `\n` for line breaks. |
| `APNS_PRODUCTION` | `true` for TestFlight / App Store; `false` only for local `flutter run` debug builds |
| `CRON_SECRET` | Any long random string (e.g. `openssl rand -hex 32`) |

CLI example:

```bash
supabase secrets set \
  APNS_KEY_ID=XXXXXXXXXX \
  APNS_TEAM_ID=WUAHMEXG3N \
  APNS_BUNDLE_ID=com.brogrammers.gotmotionapp \
  APNS_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXXXXXXXX.p8)" \
  APNS_PRODUCTION=false \
  CRON_SECRET="$(openssl rand -hex 32)"
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are usually
injected automatically for Edge Functions.

---

## D. Deploy the functions (you or ask me when secrets are set)

```bash
cd /Users/cbranch/dev/got-motion
supabase functions deploy send-push
supabase functions deploy push-morning
supabase functions deploy push-group-motion
```

---

## E. Register your phone token (you)

1. Install the latest app build on your **physical iPhone**
2. Sign in
3. **Settings → Notifications → Enable push notifications** → Allow
4. In Supabase Table Editor → `push_devices`, confirm a row for your user (`platform = ios`, `enabled = true`)

If that table is empty, push cannot deliver yet.

---

## F. Send a test push (you)

With your **user access token** (from a signed-in session) or from Dashboard → Edge Functions → `send-push` → Invoke:

```bash
curl -X POST "https://nrhtkdeyznflvcevagjc.supabase.co/functions/v1/send-push" \
  -H "Authorization: Bearer YOUR_USER_JWT" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"kind":"morning"}'
```

You should get a lock-screen alert like **“Wake up. Find your motion.”**  
and a matching row in `notifications`.

If it fails with `APNs not configured`, secrets are missing.  
If APNs returns `403` / `BadEnvironmentKeyInToken`, flip `APNS_PRODUCTION` (dev builds need `false`).

---

## G. Schedules (sparse — do not spam)

Anti-spam rule: **no hourly pushes.** People are working; morning + evening
workout windows, plus at most **1–2** group-activity checks.

| Job | Function | Cron (UTC) | ≈ Eastern |
|-----|----------|------------|-----------|
| Morning motion | `push-morning` | `0 12 * * *` | 8:00am |
| Group activity #1 | `push-group-motion` | `0 15 * * *` | 11:00am |
| Group activity #2 | `push-group-motion` | `0 20 * * *` | 4:00pm |
| Evening catch-up | `push-evening` | `0 22 * * *` | 6:00pm |
| Weekly awards | `push-weekly-awards` | `0 12 * * 1` | Monday 8:00am |

Each job: **POST**, header `x-cron-secret: <CRON_SECRET>`.

Built-in caps still apply (one morning / one evening catch-up / one group nudge
per user per day), so even if a job runs twice, users aren’t flooded.

**Supabase → Edge Functions → Schedules** (or Database → Cron) — create the
four rows above. Skip any hourly schedule.

---

## What I already built for you

| Piece | Path |
|--------|------|
| APNs sender | `supabase/functions/_shared/apns.ts` |
| Motion copy (your lines) | `supabase/functions/_shared/motion_copy.ts` |
| Test / manual push | `supabase/functions/send-push` |
| Morning job | `supabase/functions/push-morning` |
| Evening catch-up job | `supabase/functions/push-evening` |
| Weekly Monday awards | `supabase/functions/push-weekly-awards` |
| App opt-in + token storage | already in the Flutter app |
| In-app Notification Center | already working |

---

## Launch note

Before App Store / TestFlight production:
- Set `APNS_PRODUCTION=true`
- Use a Release build with `aps-environment` = `production` (we still have `development` for local device testing)

When you’ve finished **A–C**, tell me and I can help deploy + verify the test push with you.
