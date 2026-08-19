# Push notifications setup (Got Motion)

**Start here for launch:** [YOUR_PUSH_SETUP_CHECKLIST.md](./YOUR_PUSH_SETUP_CHECKLIST.md)
— that file is the short “you do this / already built” walkthrough.

App-side foundation is in place: Notification Center, preferences, APNs
registration via a native method channel, and Supabase tables for inbox /
preferences / device tokens.

Server Edge Functions are also in the repo:

- `send-push` — test / manual delivery
- `push-morning` — morning motion lines
- `push-group-motion` — “someone in your group is already moving”

They will return `APNs not configured` until you add Apple secrets (see checklist).

## Already done in the app

- In-app Notification Center (Home bell) with read/unread + badge
- Settings toggles; iOS permission requested only when the user enables push
- `notifications`, `notification_preferences`, `push_devices` migrations + RLS
- iOS Push Notifications entitlement + remote-notification background mode
- Flutter stores the APNs device token in `push_devices` after opt-in

## Apply the database migration

```bash
supabase db push
# or apply supabase/migrations/20260818200000_notifications_foundation.sql
# in the Supabase SQL editor
```

## Apple Developer / APNs

1. In [Apple Developer](https://developer.apple.com) → Certificates, Identifiers & Profiles:
   - Enable **Push Notifications** on App ID `com.brogrammers.gotmotionapp`
2. Create an **APNs Auth Key** (.p8) (or certificate) for the team
3. Note Team ID, Key ID, and Bundle ID
4. In Xcode → Signing & Capabilities, confirm **Push Notifications** is present
   (entitlement `aps-environment` is in `ios/Runner/Runner.entitlements`)

## Supabase (or Edge Function) sender

The mobile app **must not** hold APNs secrets or the service-role key.

Recommended path:

1. Store the APNs `.p8` (or cert), Key ID, and Team ID in Supabase secrets /
   Vault — never in the Flutter client
2. Add an Edge Function (or worker) that:
   - Reads eligible rows / events (rank change, catch-up, etc.)
   - Checks `notification_preferences` (`push_enabled` + category flags)
   - Loads enabled tokens from `push_devices` where `platform = 'ios'`
   - Sends via APNs HTTP/2 (`api.push.apple.com` / sandbox)
   - Inserts a matching row into `notifications` for the in-app inbox
3. Optional: use a provider (OneSignal, Firebase Cloud Messaging with APNs,
   etc.) that posts to the same tables — still keep secrets server-side

## Product voice (motion-first)

All push copy should talk about **motion**, not generic app opens.

Catalog lives in `lib/services/motion_push_copy.dart`:

- Morning: “Wake up. Find your motion.” / “Got Motion? Go make some.”
- Catch-up: “Everybody got motion but you.” / “The motion party started without you.”
- Group moving: “Q got motion early: 500 steps already.” / “Adrian is in motion. Your turn.”

Rules for senders:

- Never send merely because Health metrics are zero
- Gate morning / return nudges on last successful sync + sensible local time
- Scope competition / group alerts to the user’s current group when relevant
- Only include leaderboard-visible facts (name, steps, rank) — never private Health details beyond what the group already sees

## Verify end-to-end

1. Sign in on a physical iPhone
2. Settings → Notifications → enable push → allow system prompt
3. Confirm a row appears in `push_devices` for your user
4. From a trusted server, send a test APNs payload to that token
5. Confirm the device receives the alert and/or a new `notifications` row

Until step 4–5 work, the Notification Center may still show **sample**
in-app rows so UX can be validated without live push.
