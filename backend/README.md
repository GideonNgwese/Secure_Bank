# SecureBank auth + email backend (OTP + Brevo)

Secure REST service that powers OTP **password reset**, **email verification**,
and the full **premium transactional email system** (receipts, fraud alerts,
KYC status, admin announcements, monthly summaries, ...) via **Brevo** email,
updating Firebase through the **Admin SDK**. The Flutter app never sees the
Brevo key or Admin credentials — it only calls these endpoints. This is a
plain Node/Express server, not a Firebase Cloud Function — it runs on the
**Firebase Spark (free) plan** with no billing requirement, deployed to any
ordinary Node host.

## Endpoints
| Method | Path | Body | Purpose |
|--------|------|------|---------|
| POST | `/send-reset-code` | `{ email }` | Email a 6-digit reset code |
| POST | `/verify-reset-code` | `{ email, code }` | Check the code |
| POST | `/reset-password` | `{ email, code, newPassword }` | Update the password |
| POST | `/send-verification-code` | `{ email }` | Email a 6-digit verify code |
| POST | `/verify-email-code` | `{ email, code }` | Mark email verified |
| POST | `/send-email` | `{ eventType, recipientEmail, recipientName, templateData, targetUserId?, queueId? }` + `Authorization: Bearer <Firebase ID token>` | Renders + sends one of the 19 premium email types (see `templates/renderers.js`) |
| POST | `/brevo-webhook` | Brevo's own payload | Updates `email_queue` status to `opened`/`clicked`/`delivered` |

OTPs are 6 digits, hashed at rest in Firestore (`auth_otps`), expire in 10 min,
and lock after 5 wrong attempts. Basic rate limiting is applied per IP.

### `/send-email` details
- Requires a valid Firebase ID token (the same one the Flutter app already
  holds once signed in). The caller must either be sending to themself, or be
  an admin sending on another user's behalf (`targetUserId`) — checked via
  the same `users/{uid}.role == 'admin'` convention the rest of the app uses.
- Writes/updates a `email_queue/{queueId}` Firestore doc as it goes
  (`sending` → `delivered`/`failed`), using the Admin SDK — Firestore rules
  block clients from writing that field directly, so this is the only path
  status ever changes on. The Flutter app streams that doc for live delivery
  status.
- Retries the Brevo call up to 3 times with a short backoff before marking
  `failed` — a failure is logged server-side and returned as a normal 200
  with `failed: true` (never a 500), so a flaky email never surfaces as a
  broken request to the app; `EmailRepository` on the Flutter side treats
  every send as best-effort regardless.

### `/brevo-webhook` setup (optional — Opened/Clicked tracking)
In your Brevo dashboard: **Transactional → Settings → Webhooks** → add
`https://YOUR-DEPLOYED-URL/brevo-webhook`, subscribed to `delivered`,
`opened`, `click`. Without this, delivery status still tracks
`queued → sending → delivered/failed` from the send call itself — only the
Opened/Clicked stages depend on the webhook.

## 1. Get the credentials
- **Brevo API key:** Brevo dashboard → *SMTP & API → API Keys → Generate*.
- **Brevo sender:** *Senders, Domains & Dedicated IPs → Senders* — add and verify
  a sender address (e.g. `no-reply@yourdomain.com`). Emails from a verified
  sender/domain land in the inbox, not spam.
- **Firebase service account:** [Firebase Console](https://console.firebase.google.com/project/bank-b6112/settings/serviceaccounts/adminsdk)
  → *Service accounts → Generate new private key* → save as
  `backend/serviceAccountKey.json`.

## 2. Configure
```bash
cd backend
cp .env.example .env
# fill in BREVO_API_KEY, BREVO_SENDER_EMAIL, OTP_SALT, and the service account
```

## 3. Run
```bash
npm install
npm start        # http://localhost:8080  (GET /health → { ok: true })
```

## 4. Point the app at it
Run the Flutter app with the backend URL (and it switches from Firebase emails
to Brevo OTP automatically):
```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-DEPLOYED-URL
```
For local testing on a physical device, use your machine's LAN IP (not
`localhost`), e.g. `--dart-define=API_BASE_URL=http://192.168.1.50:8080`, and
allow cleartext for that host (or deploy behind HTTPS).

## 5. Deploy (any Node host)
Render / Railway / Fly.io / Cloud Run all work. Set the same env vars there
(paste the service account JSON into `FIREBASE_SERVICE_ACCOUNT` instead of a
file). Then use the public HTTPS URL as `API_BASE_URL`.

## Cloudinary (profile photos / KYC documents)
The app **uploads directly** to Cloudinary using an **unsigned preset** — no
backend needed for uploads, and no secret in the app:
1. Create a free account at cloudinary.com → note your **cloud name**.
2. Settings → **Upload** → *Add upload preset* → set **Signing Mode: Unsigned**
   → save its name.
3. Run the app with:
   ```bash
   flutter run \
     --dart-define=CLOUDINARY_CLOUD_NAME=your-cloud-name \
     --dart-define=CLOUDINARY_UPLOAD_PRESET=your-unsigned-preset
   ```
Uploads then work (profile photo + KYC document). **Deleting** an asset needs the
API secret, so the app calls this backend's `POST /cloudinary/delete` — set
`CLOUDINARY_*` in `.env` for that.

## Notes
- `/send-reset-code` always responds 200 (even for unknown emails) to avoid
  leaking which addresses are registered.
- Never commit `.env` or `serviceAccountKey.json` (already in `.gitignore`).
