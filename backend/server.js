/**
 * SecureBank auth backend — OTP + Brevo email + Firebase Admin.
 *
 * Endpoints (all JSON):
 *   POST /send-reset-code        { email }
 *   POST /verify-reset-code      { email, code }
 *   POST /reset-password         { email, code, newPassword }
 *   POST /send-verification-code { email }
 *   POST /verify-email-code      { email, code }
 *   POST /send-email             { eventType, recipientEmail, recipientName, templateData, targetUserId? }
 *                                 Authorization: Bearer <Firebase ID token>
 *   POST /brevo-webhook          Brevo delivery/open/click events (public; see README)
 *
 * Secrets (Brevo key, Firebase Admin credentials, OTP salt) live only here —
 * never in the Flutter app. See README.md for setup + deployment.
 */
require('dotenv').config();
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const axios = require('axios');
const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;
const { RENDERERS } = require('./templates/renderers');
const { BRAND, wrapEmail } = require('./templates/layout');

// ---- Cloudinary (only needed for DELETE; uploads are unsigned from the app) ----
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// ---- Firebase Admin ----
// Provide credentials via GOOGLE_APPLICATION_CREDENTIALS (path to the service
// account JSON) or FIREBASE_SERVICE_ACCOUNT (the JSON string itself).
if (!admin.apps.length) {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  admin.initializeApp({
    credential: raw
      ? admin.credential.cert(JSON.parse(raw))
      : admin.credential.applicationDefault(),
  });
}
const db = admin.firestore();
const auth = admin.auth();

// ---- Config ----
const PORT = process.env.PORT || 8080;
const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const MAX_ATTEMPTS = 5;
const OTP_SALT = process.env.OTP_SALT || 'change-me';
const BREVO_API_KEY = process.env.BREVO_API_KEY;
const SENDER = {
  email: process.env.BREVO_SENDER_EMAIL,
  name: process.env.BREVO_SENDER_NAME || 'SecureBank',
};

// ---- Helpers ----
const hash = (code) =>
  crypto.createHash('sha256').update(`${code}:${OTP_SALT}`).digest('hex');
const genCode = () => String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
const otpDoc = (purpose, email) =>
  db.collection('auth_otps').doc(`${purpose}:${email.toLowerCase().trim()}`);

/** Sends via Brevo and returns its messageId (used for delivery tracking). */
async function sendBrevoEmail(toEmail, subject, htmlContent, toName) {
  const res = await axios.post(
    'https://api.brevo.com/v3/smtp/email',
    {
      sender: SENDER,
      to: [{ email: toEmail, name: toName || undefined }],
      subject,
      htmlContent,
    },
    { headers: { 'api-key': BREVO_API_KEY, 'Content-Type': 'application/json' } }
  );
  return res.data?.messageId;
}

function codeEmailHtml(code, purpose) {
  const title =
    purpose === 'verify' ? 'Verify your email' : 'Reset your password';
  return wrapEmail({
    title,
    preheader: `Your code: ${code}`,
    bodyHtml: `<p>Use this code to continue. It expires in 10 minutes.</p>
      <div style="font-size:32px;font-weight:800;letter-spacing:10px;background:${BRAND.card};color:${BRAND.ink};padding:18px;border-radius:14px;text-align:center;margin:16px 0;">${code}</div>
      <p style="color:${BRAND.muted};font-size:12px;">If you didn't request this, you can safely ignore this email.</p>`,
  });
}

async function issueCode(purpose, email) {
  const code = genCode();
  await otpDoc(purpose, email).set({
    codeHash: hash(code),
    expiresAt: Date.now() + OTP_TTL_MS,
    attempts: 0,
    createdAt: Date.now(),
  });
  await sendBrevoEmail(
    email,
    purpose === 'verify' ? 'Your SecureBank verification code'
                         : 'Your SecureBank password reset code',
    codeEmailHtml(code, purpose)
  );
}

async function checkCode(purpose, email, code) {
  const ref = otpDoc(purpose, email);
  const snap = await ref.get();
  if (!snap.exists) return { ok: false, message: 'Request a new code.' };
  const data = snap.data();
  if (Date.now() > data.expiresAt) {
    await ref.delete();
    return { ok: false, message: 'This code has expired. Request a new one.' };
  }
  if (data.attempts >= MAX_ATTEMPTS) {
    await ref.delete();
    return { ok: false, message: 'Too many attempts. Request a new code.' };
  }
  if (data.codeHash !== hash(String(code))) {
    await ref.update({ attempts: data.attempts + 1 });
    return { ok: false, message: 'Incorrect code. Please try again.' };
  }
  return { ok: true };
}

const isEmail = (v) => typeof v === 'string' && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v);

// ---- App ----
const app = express();
app.use(cors());
app.use(express.json());
app.use(
  rateLimit({ windowMs: 60 * 1000, max: 12, standardHeaders: true })
);

const wrap = (fn) => (req, res) =>
  fn(req, res).catch((e) => {
    console.error(e?.response?.data || e);
    res.status(500).json({ message: 'Something went wrong. Please try again.' });
  });

app.get('/health', (_req, res) => res.json({ ok: true }));

// --- Password reset ---
app.post('/send-reset-code', wrap(async (req, res) => {
  const { email } = req.body;
  if (!isEmail(email)) return res.status(400).json({ message: 'Invalid email.' });
  // Don't reveal whether the account exists; only email a code if it does.
  try {
    await auth.getUserByEmail(email);
    await issueCode('reset', email);
  } catch (_) { /* no such user — respond 200 anyway */ }
  res.json({ message: 'If that email exists, a code has been sent.' });
}));

app.post('/verify-reset-code', wrap(async (req, res) => {
  const { email, code } = req.body;
  const result = await checkCode('reset', email, code);
  if (!result.ok) return res.status(400).json({ message: result.message });
  res.json({ message: 'Code verified.' });
}));

app.post('/reset-password', wrap(async (req, res) => {
  const { email, code, newPassword } = req.body;
  if (typeof newPassword !== 'string' || newPassword.length < 8) {
    return res.status(400).json({ message: 'Password must be at least 8 characters.' });
  }
  const result = await checkCode('reset', email, code);
  if (!result.ok) return res.status(400).json({ message: result.message });
  const user = await auth.getUserByEmail(email);
  await auth.updateUser(user.uid, { password: newPassword });
  await otpDoc('reset', email).delete();
  res.json({ message: 'Password updated.' });

  // Confirmation email — sent server-side because the Flutter app has no
  // authenticated session at this point (password reset is a pre-auth
  // flow), so it can't call the authenticated /send-email endpoint itself.
  // Fire-and-forget: the response above has already gone out.
  renderAndSendEmail({
    eventType: 'password_reset',
    userId: user.uid,
    recipientEmail: email,
    recipientName: user.displayName || '',
    templateData: { time: new Date().toISOString() },
  }).catch((e) => console.error('password_reset confirmation email failed:', e.message));
}));

// --- Email verification (Brevo OTP) ---
app.post('/send-verification-code', wrap(async (req, res) => {
  const { email } = req.body;
  if (!isEmail(email)) return res.status(400).json({ message: 'Invalid email.' });
  await auth.getUserByEmail(email); // must exist
  await issueCode('verify', email);
  res.json({ message: 'Verification code sent.' });
}));

app.post('/verify-email-code', wrap(async (req, res) => {
  const { email, code } = req.body;
  const result = await checkCode('verify', email, code);
  if (!result.ok) return res.status(400).json({ message: result.message });
  const user = await auth.getUserByEmail(email);
  await auth.updateUser(user.uid, { emailVerified: true });
  await otpDoc('verify', email).delete();
  res.json({ message: 'Email verified.' });
}));

// --- Cloudinary delete (secret stays server-side) ---
app.post('/cloudinary/delete', wrap(async (req, res) => {
  const { publicId } = req.body;
  if (!publicId) return res.status(400).json({ message: 'publicId is required.' });
  await cloudinary.uploader.destroy(publicId);
  res.json({ message: 'Deleted.' });
}));

// --- Transactional email (Part 3: 9-event premium email system) ---
//
// The Flutter app never talks to Brevo directly — it writes an
// `email_queue` doc (audit trail, read by the client for delivery status)
// and calls this endpoint with a Firebase ID token. This endpoint verifies
// the token, renders the right branded template, sends via Brevo, retries
// on transient failure, and updates the queue doc via the Admin SDK (which
// bypasses Firestore rules — the rules deliberately disallow client writes
// to `status` so only this trusted server can move it forward).
async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ message: 'Missing Authorization header.' });
  try {
    req.uid = (await auth.verifyIdToken(token)).uid;
    next();
  } catch (e) {
    res.status(401).json({ message: 'Invalid or expired session. Please sign in again.' });
  }
}

async function isAdminUid(uid) {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists && snap.data().role === 'admin';
}

const EMAIL_MAX_ATTEMPTS = 3;

/**
 * Renders + sends one templated email, retrying up to EMAIL_MAX_ATTEMPTS
 * times, and tracks the attempt in `email_queue` via the Admin SDK. Shared
 * by the authenticated `/send-email` endpoint AND server-triggered emails
 * that have no Flutter-side caller to authenticate (e.g. the password-reset
 * confirmation below, sent right after a successful OTP-verified reset).
 */
async function renderAndSendEmail({ eventType, userId, recipientEmail, recipientName, templateData, queueId }) {
  const renderer = RENDERERS[eventType];
  if (!renderer) throw new Error(`Unknown eventType: ${eventType}`);

  const queueRef = queueId
    ? db.collection('email_queue').doc(queueId)
    : db.collection('email_queue').doc();
  await queueRef.set(
    {
      eventType,
      userId,
      recipientEmail,
      recipientName: recipientName || '',
      status: 'sending',
      attempts: 0,
      updatedAt: new Date().toISOString(),
    },
    { merge: true }
  );

  const { subject, html } = renderer({ name: recipientName, ...templateData });

  let lastError;
  for (let attempt = 1; attempt <= EMAIL_MAX_ATTEMPTS; attempt++) {
    try {
      const messageId = await sendBrevoEmail(recipientEmail, subject, html, recipientName);
      await queueRef.set(
        {
          status: 'delivered',
          attempts: attempt,
          brevoMessageId: messageId || null,
          sentAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        },
        { merge: true }
      );
      return { queueId: queueRef.id, failed: false };
    } catch (e) {
      lastError = e?.response?.data?.message || e.message || 'Unknown error';
      if (attempt < EMAIL_MAX_ATTEMPTS) {
        await new Promise((r) => setTimeout(r, attempt * 500)); // brief backoff
      }
    }
  }

  console.error(`Email send failed for ${eventType} -> ${recipientEmail}: ${lastError}`);
  await queueRef.set(
    {
      status: 'failed',
      attempts: EMAIL_MAX_ATTEMPTS,
      lastError: String(lastError).slice(0, 500),
      updatedAt: new Date().toISOString(),
    },
    { merge: true }
  );
  return { queueId: queueRef.id, failed: true };
}

app.post('/send-email', requireAuth, wrap(async (req, res) => {
  const { eventType, recipientEmail, recipientName, templateData, targetUserId, queueId } = req.body;

  if (!isEmail(recipientEmail)) {
    return res.status(400).json({ message: 'A valid recipientEmail is required.' });
  }
  if (!RENDERERS[eventType]) {
    return res.status(400).json({ message: `Unknown eventType: ${eventType}` });
  }

  // The caller must be sending their own email, or be an admin sending on
  // behalf of another user (KYC decisions, announcements, suspensions...).
  const owner = targetUserId || req.uid;
  if (owner !== req.uid && !(await isAdminUid(req.uid))) {
    return res.status(403).json({ message: 'Not authorized to send this email.' });
  }

  const result = await renderAndSendEmail({
    eventType, userId: owner, recipientEmail, recipientName, templateData, queueId,
  });
  // Failure never surfaces as a 500 that could look like the whole request
  // broke — the caller (EmailRepository) already treats email as best-effort
  // and won't let this interrupt the user's main action either way.
  res.status(200).json(result.failed
    ? { message: 'Email could not be delivered and was logged for retry.', ...result }
    : { message: 'Sent.', ...result });
}));

// --- Brevo webhook: Opened / Clicked delivery-status events ---
// Configure this URL in Brevo -> Transactional -> Settings -> Webhooks.
// Public endpoint (Brevo can't send a Firebase ID token), so it's narrowed
// to only ever update a doc matched by Brevo's own messageId.
app.post('/brevo-webhook', wrap(async (req, res) => {
  const events = Array.isArray(req.body) ? req.body : [req.body];
  for (const evt of events) {
    const messageId = evt['message-id'] || evt.messageId;
    const eventName = evt.event; // 'delivered' | 'opened' | 'click' | 'hard_bounce' | ...
    if (!messageId || !eventName) continue;
    const status = { opened: 'opened', click: 'clicked', delivered: 'delivered' }[eventName];
    if (!status) continue;
    const snap = await db.collection('email_queue').where('brevoMessageId', '==', messageId).limit(1).get();
    if (!snap.empty) {
      await snap.docs[0].ref.set({ status, updatedAt: new Date().toISOString() }, { merge: true });
    }
  }
  res.json({ ok: true });
}));

app.listen(PORT, () => console.log(`SecureBank backend on :${PORT}`));
