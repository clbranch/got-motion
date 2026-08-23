# Build queue

Track what ships in each TestFlight build. **Build 14** is live; **Build 15** is the current batch.

When you ask for a feature or fix, it gets added here under **Build 15** until we cut the IPA.

---

## Build 15 (in progress) — `1.0.0+15`

### Done (in repo, not on TestFlight yet)

- [x] **Performance** — cap HealthKit history sync (no more 730-day hammer on launch)
- [x] **Leaderboard speed** — don’t load until tab opens; reuse cached groups; parallel Supabase queries; show rows before Health; no reload loop
- [x] **Performance** — Health timeouts so spinners don’t hang forever
- [x] **Performance** — Profile loads only when that tab is opened
- [x] **Performance** — Debounce Leaderboard refresh when switching tabs
- [x] **Tooling** — `tool/export_ipa.sh` for Transporter exports after Xcode sign-in
- [x] **Workout proof cleanup** — edge function deletes proof photos/videos after 7 days
- [x] **Proof UX** — copy on finish sheet: photo preferred, proof auto-removed after ~7 days

### Still before ship

- [ ] **Deploy cleanup cron** — schedule `cleanup-workout-proofs` edge function (daily)

### Queued (ideas — add to this build when ready)

- [ ] **“Log in Fitness”** — optional button on workout flow for phone-only users

### TestFlight release notes (draft)

```
Build 15
- Much faster screen loads (Home, Leaderboard, Settings)
- Fixed spinners freezing or taking too long
- Workout proof photos/videos auto-delete after 7 days (workout log stays)
- Includes Build 14 fixes (tab scroll, double-spinner, invites, Health)
```

---

## Shipped

| Build | Highlights |
|-------|------------|
| **14** | Tab scroll reset, double-spinner fix, group invite RPC, HealthKit single-auth |
| **13** | Leaderboard double-spinner when no group |
| **12** | Invite link join, Health timeouts, Android deep link |
| **11** | In-app workouts, Fitness-style UI |

---

## How we use this

1. You ask for something → it lands under **Build 15 → Queued**
2. We implement → move to **Done**
3. When you’re ready to ship → `flutter build ipa` / Transporter → tick **Shipped** and start **Build 16** section
