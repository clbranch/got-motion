# Build queue

**Build 16** = App Store resubmit batch. Don’t cut IPA until Must-ship is done.

---

## Build 18 — `1.0.0+18`

### Done
- [x] Profile history: colored metric chart + totals (steps / calories / miles); legend switches the bars
- [x] Build 17: removed invalid `healthkit` UIBackgroundModes (Transporter 409)

### Carry-forward from Build 16/17
- Sign in with Apple, login hang fixes, leaderboard digests, background Health, last-synced


### Done
- [x] **2.1(a)** — No infinite spinner after login (timeouts on AuthGate / Home / Profile / Health)
- [x] **4.8** — Sign in with Apple (login UI + entitlements)

### Product decisions (locked in)

**Health**
- Prefer **Apple Watch** when present; always include **third-party apps that write to Apple Health** (cousin logs in his app → Health → Got Motion).
- Native HealthKit path already merges third-party; Dart fallback must not drop “other” sources when there’s no Watch.

**Notifications**
- Remove “get moving” morning/evening copy (`Morning motion` / `Evening motion`).
- Same schedule slots → **leaderboard digests** instead.
- **One digest push**, not one per group (avoids 10 alerts if you’re in 10 groups).
- Only include groups where you’re in the **top 3**.
- Copy: place + gap to 1st (“You’re 2nd in Mighty Ducks — 4,200 steps from the lead”).

**History**
- Personal past weeks/months live on **Profile** (replace redundant bottom “This Week”).
- Not a global “everyone’s past months” on Leaderboard (that stays Today / Week / Month-to-date).

### Must ship
- [x] Notifications: kill get-moving; top-3 digest with gap-to-1st; update Settings labels
- [x] Profile: replace This Week with personal history (week / month / prior months)
- [x] Health: Watch preferred + third-party Health sources included (Dart fallback)
- [x] Background Health sync + last-synced on Leaderboard
- [ ] Manual: Apple Sign In capability + Supabase Apple provider + IPA + App Review reply
  - Push Edge Functions deployed (`push-morning`, `push-evening`, `push-group-motion`)
  - Migration `daily_steps.synced_at` applied on remote

### Deferred
- [ ] Workout proof cleanup cron deploy
- [ ] Log in Fitness button
- [ ] Pushup / rep counting

### Release notes (draft)
```
Build 16
- Sign in with Apple
- Fixed hang after login
- Leaderboard digests (top 3 in your groups) — no more “get moving” spam
- Profile history for past weeks/months
- Better Health sync (Watch + apps that write to Health)
- Background Health updates + “last synced” on Leaderboard
```
