# Got Motion marketing site (`gotmotion.app`)

Static site for App Store Privacy / Support URLs and a simple brand landing page.

## Local preview

```bash
cd web
python3 -m http.server 8080
# open http://localhost:8080
```

## Deploy to Vercel (recommended)

1. [vercel.com](https://vercel.com) → Add New Project → import this repo
2. Set **Root Directory** to `web`
3. Deploy
4. Project → Domains → add `gotmotion.app` and `www.gotmotion.app`
5. At your domain registrar (where the domain is ACTIVE), point DNS as Vercel shows (usually A / CNAME records)

## App Store Connect URLs (after DNS is live)

| Field | URL |
|--------|-----|
| Privacy Policy | `https://gotmotion.app/privacy` |
| Support | `https://gotmotion.app/support` |
| Marketing (optional) | `https://gotmotion.app` |

Create the mailbox `support@gotmotion.app` (or forward it) so Support emails work.
