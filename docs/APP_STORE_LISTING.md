# App Store Connect — paste-ready listing (Got Motion)

Bundle ID: `com.brogrammers.gotmotionapp`  
Apple ID: `6760286311`  
Version: **1.0.0** (build **6**)

---

## App Information

| Field | Value |
|--------|--------|
| **Name** | Got Motion |
| **Subtitle** (30 chars max) | `Compete with friends` |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Social Networking *(optional)* |

**Subtitle alternatives** (if you prefer):
- `Group fitness competition` (26)
- `Stay in motion together` (23)

---

## Age Ratings — what to answer

Click **Set Up Age Ratings** and use these answers for Got Motion:

| Topic | Answer | Why |
|--------|--------|-----|
| Parental Controls / Age Assurance | **None** | No parental-control feature |
| Unrestricted Web Access | **No** | No in-app browser to the open web |
| User-Generated Content | **Infrequent/Mild** *or* **None** if Apple frames it as “social networking UGC” | Display names + optional profile/group photos only — no public feed/chat |
| Messaging / Chat | **None** | No chat |
| Social Networking features | **Infrequent** if asked (groups/leaderboards) | Private groups, not a public social network |
| Profanity / Crude Humor | **None** | |
| Horror / Fear | **None** | |
| Alcohol / Tobacco / Drugs | **None** | |
| Medical or Treatment Info | **None** | Fitness competition, not medical advice or treatment |
| Health / Wellness topics | **Infrequent** if the form distinguishes “wellness” | Steps/activity competition; not clinical |
| Sexuality / Nudity | **None** | |
| Violence (all types) | **None** | |
| Gambling / Contests / Loot Boxes | **None** *(leaderboards are skill/activity, not chance)* | |

Expected outcome: typically **4+**.

Also complete any **new social media age questions** from the ASC banner using the same spirit (private groups, no public feed).

---

## Version page (1.0 Prepare for Submission)

### Promotional Text (170 chars max)
```
Got Motion turns daily steps and activity into friendly group competition. Sync Apple Health, climb the leaderboard, and stay in motion with your crew.
```

### Description
```
Got Motion is group fitness competition built around real daily activity.

Compete with friends in private groups. Sync steps, distance, active calories, and exercise minutes from Apple Health. See today’s progress, climb the leaderboard, and get motion-first nudges that keep you moving — not spam.

WHAT YOU CAN DO
• Create or join a group and compete together
• Sync Apple Health for steps, miles, calories, and exercise
• Track today, this week, and category leaders
• Invite friends with a simple invite code
• Opt into push alerts for morning motion, evening catch-up, and group activity

Got Motion is for friendly competition — not medical diagnosis or treatment. You control Health access in Apple Health settings at any time.
```

### Keywords (100 chars, comma-separated, no spaces after commas preferred)
```
steps,fitness,leaderboard,health,competition,walking,calories,groups,exercise,apple health
```

### Support URL
```
https://gotmotion.app/support
```

### Marketing URL (optional)
```
https://gotmotion.app
```

### Privacy Policy URL (required)
```
https://gotmotion.app/privacy
```

Marketing site source: [`web/`](../web/) — deploy and point DNS for `gotmotion.app` (see `web/README.md`).

---

## App Privacy (nutrition labels)

Declare data collected:

| Category | Data | Linked to user? | Used for tracking? |
|----------|------|-----------------|-------------------|
| Contact Info | Email, Name | Yes | No |
| Health & Fitness | Fitness / activity (steps, energy, exercise, distance) | Yes | No |
| User Content | Photos / avatars | Yes | No |
| Identifiers | User ID | Yes | No |

**Health:** Used for App Functionality (leaderboards / progress). **Not** for advertising. **Not** sold.  
**Product purpose:** App Functionality, Account Management.

---

## Encryption
Info.plist includes `ITSAppUsesNonExemptEncryption = false` (standard HTTPS / Apple OS crypto only). In the export compliance question, answer that you only use exempt encryption.

---

## Screenshots checklist

Capture on iPhone (6.7" and/or 6.1" slots in ASC):

1. Home — today’s motion + group
2. Leaderboard
3. Group members
4. Profile / today’s progress ring
5. (Optional) Notifications or Settings

App icon 1024×1024 is already in the iOS asset catalog (`AppIcon-1024.png`).

---

## After build upload
1. Wait for build to process in TestFlight / ASC
2. Select build on version 1.0
3. Answer HealthKit questions: reads activity for competition/leaderboards; not for clinical use
4. Submit for Review
