# Got Motion — Supabase Auth email templates

Paste each HTML file into **Supabase → Authentication → Email Templates**.

| File | Supabase template | Suggested subject |
|------|-------------------|-------------------|
| `confirm-signup.html` | Confirm signup | Confirm your Got Motion account |
| `magic-link.html` | Magic Link | Sign in to Got Motion |
| `change-email.html` | Change Email Address | Confirm your new email — Got Motion |
| `invite-user.html` | Invite user | You're invited to Got Motion |
| `reset-password.html` | Reset password | Reset your Got Motion password |
| `password-changed.html` | Security → Password changed | Your Got Motion password was changed |
| `email-address-changed.html` | Security → Email address changed | Your Got Motion email was changed |

For each template: open **Source**, select all, paste the file contents, set the subject, **Save**.

Security notifications: **Authentication → Emails → Security** — enable the toggle, click the row, paste HTML, set subject.

Logo is embedded (base64) so it renders without external image hosting.
Regenerate after logo changes: `dart run tool/generate_auth_email_templates.dart`
