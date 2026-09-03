# App Store rejection fixes (resubmit build 16)

Apple rejected **1.0 (7)** for:
1. **2.1(a)** — infinite loading after login
2. **4.8** — Google login without Sign in with Apple

## Code changes (in this build)

- Hard timeouts on AuthGate boot, Home/Profile loads, Health auth, and leaderboard fetches so the UI always paints
- **Continue with Apple** on the login screen (native Sign in with Apple → Supabase)
- iOS entitlements: `com.apple.developer.applesignin`
- HealthKit background delivery + Leaderboard “last synced” labels (`daily_steps.synced_at`)

## You must do these once before upload

### 1. Apple Developer — Sign in with Apple capability

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **com.brogrammers.gotmotionapp**
2. Enable **Sign In with Apple** → Save
3. In Xcode: open `ios/Runner.xcworkspace` → Runner target → **Signing & Capabilities** → confirm **Sign in with Apple** is listed (entitlements files already updated)
4. Confirm **HealthKit** capability includes **Background Delivery** (entitlement `com.apple.developer.healthkit.background-delivery` is in the repo)

### 2. Supabase — enable Apple provider

1. [Supabase Dashboard](https://supabase.com/dashboard/project/nrhtkdeyznflvcevagjc/auth/providers) → **Authentication → Providers → Apple**
2. Turn **Apple** ON
3. Under Client IDs, add: `com.brogrammers.gotmotionapp`
4. Save

Native iOS Sign in with Apple does **not** need a Services ID / secret for the basic native flow when using the bundle ID as client ID.

### 3. Supabase — apply migration + deploy push functions

```bash
supabase db push
supabase functions deploy push-morning
supabase functions deploy push-evening
supabase functions deploy push-group-motion
```

Migration adds `daily_steps.synced_at` for Leaderboard last-synced labels.

### 4. Review reply (paste in App Store Connect)

```
Thank you for the feedback.

2.1(a) — We fixed the post-login hang. Home and Profile no longer wait indefinitely on HealthKit or network; screens always render within a few seconds even if Health permission is delayed.

4.8 — We added Sign in with Apple as an equivalent login option alongside Google and email/password. Sign in with Apple limits data to name/email, supports Hide My Email, and does not collect advertising interactions.

Please re-review build 1.0 (17).
```

### 5. Demo account for Review

Use the existing App Review account if still valid, or create a fresh email/password account and put it in **App Review Information**.

### Note — Transporter / UIBackgroundModes

Do **not** put `healthkit` in `UIBackgroundModes`. App Store validation rejects it (409). Background HealthKit uses the entitlement `com.apple.developer.healthkit.background-delivery` only.
