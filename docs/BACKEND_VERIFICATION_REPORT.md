# Backend verification report

Generated after auth/profile/group upgrade and automated backend finalization.

---

## 1. What is already configured

### Migrations (applied successfully)

- **20260308120000_profiles.sql** was applied:
  - `public.profiles` table exists with: `id`, `email`, `full_name`, `username`, `display_name`, `avatar_url`, `updated_at`
  - RLS enabled; policies: "Users can read own profile", "Users can update own profile", "Users can read profiles in same group"
  - Trigger `on_auth_user_created` on `auth.users` → `public.handle_new_user()` (creates/updates profile on signup)
  - Backfill: `INSERT ... FROM auth.users ON CONFLICT (id) DO UPDATE` ran so existing users have profile rows

- **20260308120001_storage_avatars.sql** was applied:
  - `storage.buckets`: `avatars` bucket (public, 2MB limit, image MIME types)
  - RLS on `storage.objects`: "Users can upload own avatar", "Users can update own avatar", "Avatar images are publicly readable"

- **group_invites** (from earlier migration 20260307200000):
  - Unique constraint for pending invites: `group_invites_pending_unique` on `(group_id, lower(trim(invited_email))) WHERE status = 'pending'`

### Edge Function

- **send-invite-email** is deployed and ACTIVE (JWT verification enabled).
- Invoke from client: `supabase.functions.invoke('send-invite-email', body: { 'invite_id': inviteId })`.

---

## 2. What was automatically fixed

- **Migrations**: Pushed to remote with `supabase db push` (profiles + storage).
- **Edge Function**: Deployed with `supabase functions deploy send-invite-email`.
- **Project link**: Confirmed linked to project ref `nrhtkdeyznflvcevagjc`.

---

## 3. What still requires manual setup

### Resend integration (required for invite emails)

- **RESEND_API_KEY**
  - Set in Supabase: Dashboard → Project Settings → Edge Functions → Secrets, or:
    ```bash
    supabase secrets set RESEND_API_KEY=re_xxxxxxxx
    ```
  - Get key from https://resend.com (API Keys).

- **FROM_EMAIL** (optional but recommended for production)
  - Default in code: `Got Motion <onboarding@resend.dev>` (Resend test sender).
  - For production, verify a domain in Resend and set:
    ```bash
    supabase secrets set FROM_EMAIL="Got Motion <noreply@yourdomain.com>"
    ```

### Optional: verify in Dashboard

(Docker was not available, so remote DB dump could not be run. You can confirm in the Supabase Dashboard.)

1. **Database → Tables**
   - `public.profiles`: columns include `avatar_url`, `username`, `display_name`.
   - **Database → Triggers**: `auth.users` has trigger `on_auth_user_created`.

2. **Storage → Buckets**
   - `avatars` bucket exists and is public.

3. **Database → group_invites**
   - Indexes include `group_invites_pending_unique` (unique on `(group_id, lower(trim(invited_email)))` where `status = 'pending'`).

---

## 4. Testing the invite flow

1. Set `RESEND_API_KEY` (and optionally `FROM_EMAIL`) as above.
2. In the app: sign in → open a group → Invite by email → enter an address.
3. Expected: DB row in `group_invites`; Edge Function runs; Resend sends email (or you see “Invite saved, but we couldn’t send the email” if Resend fails).
4. Check function logs: Dashboard → Edge Functions → send-invite-email → Logs (success or Resend error).

---

## 5. Summary

| Item                         | Status        | Notes                                      |
|------------------------------|---------------|--------------------------------------------|
| profiles table               | Applied       | Via migration push                         |
| avatar_url column            | Applied       | In profiles migration                     |
| Trigger on auth.users        | Applied       | handle_new_user                            |
| Profiles backfill            | Applied       | In same migration                          |
| avatars bucket               | Applied       | Via storage migration                     |
| Storage RLS (upload/update) | Applied       | Own path only                              |
| group_invites unique pending | In migration  | Already in 20260307200000                  |
| send-invite-email function   | Deployed      | ACTIVE, JWT on                             |
| RESEND_API_KEY               | Manual        | Set in Dashboard or `supabase secrets set` |
| FROM_EMAIL                   | Optional      | Set for production sender                 |
