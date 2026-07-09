/**
 * Shared branded HTML shell every SecureBank transactional email renders
 * inside — blue gradient header, rounded white card, muted detail rows,
 * pill CTA button, footer with a support link. Table-based markup
 * deliberately (not flexbox/grid): this needs to render correctly in
 * Outlook/Gmail/Apple Mail, which have wildly inconsistent CSS support —
 * tables are still the only genuinely portable layout primitive for email.
 */

const BRAND = {
  name: 'SecureBank',
  primary: '#3E74FF',
  primaryDeep: '#2348C8',
  ink: '#0A1B3D',
  muted: '#7A8699',
  mutedLight: '#A6B0C3',
  bg: '#F1F4F9',
  card: '#F7F9FC',
  border: '#E7ECF3',
  success: '#1FA96A',
  warning: '#E8A33D',
  danger: '#EF4E4E',
  supportEmail: 'support@securebank.app',
};

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

/** One label/value row inside a details card. */
function detailRow(label, value) {
  return `<tr>
    <td style="padding:9px 0;font-size:13px;color:${BRAND.muted};border-bottom:1px solid ${BRAND.border};">${escapeHtml(label)}</td>
    <td style="padding:9px 0;font-size:13px;color:${BRAND.ink};font-weight:600;text-align:right;border-bottom:1px solid ${BRAND.border};">${escapeHtml(value)}</td>
  </tr>`;
}

/** A muted rounded card wrapping a set of [detailRow] strings. */
function detailsCard(rowsHtml) {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${BRAND.card};border-radius:14px;padding:4px 18px;margin:18px 0;">
    ${rowsHtml.join('')}
  </table>`;
}

/** A tinted callout box — used for security advice / warnings / tips. */
function calloutBox(text, { color = BRAND.primary, icon = '🛡️' } = {}) {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${color}14;border-left:3px solid ${color};border-radius:10px;margin:18px 0;">
    <tr><td style="padding:14px 16px;font-size:12.5px;color:${BRAND.ink};line-height:1.5;">
      <span style="margin-right:6px;">${icon}</span>${text}
    </td></tr>
  </table>`;
}

function pillButton(label, url) {
  if (!label || !url) return '';
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin-top:22px;">
    <tr><td style="border-radius:999px;background:${BRAND.primary};">
      <a href="${escapeHtml(url)}" style="display:inline-block;padding:14px 30px;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;border-radius:999px;font-family:'Segoe UI',Helvetica,Arial,sans-serif;">${escapeHtml(label)}</a>
    </td></tr>
  </table>`;
}

/** The reference-number footer row every financial email should carry. */
function referenceLine(referenceNumber) {
  if (!referenceNumber) return '';
  return `<p style="margin:18px 0 0;font-size:11px;color:${BRAND.mutedLight};">Reference: ${escapeHtml(referenceNumber)}</p>`;
}

/**
 * Wraps [bodyHtml] in the full branded shell.
 * @param {{title:string, preheader?:string, bodyHtml:string, ctaLabel?:string, ctaUrl?:string, accent?:string}} opts
 */
function wrapEmail({ title, preheader = '', bodyHtml, ctaLabel, ctaUrl, accent = BRAND.primary }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta name="color-scheme" content="light dark" />
<title>${escapeHtml(title)}</title>
</head>
<body style="margin:0;padding:0;background:${BRAND.bg};font-family:'Segoe UI',Helvetica,Arial,sans-serif;">
${preheader ? `<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escapeHtml(preheader)}</div>` : ''}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${BRAND.bg};padding:32px 16px;">
  <tr><td align="center">
    <table role="presentation" width="100%" style="max-width:560px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 8px 24px rgba(10,27,61,0.08);">
      <tr><td style="background:linear-gradient(135deg,${accent},${BRAND.primaryDeep});padding:28px 32px;">
        <span style="color:#ffffff;font-size:21px;font-weight:800;letter-spacing:-0.3px;">🛡️ ${BRAND.name}</span>
      </td></tr>
      <tr><td style="padding:32px;">
        <h1 style="margin:0 0 4px;font-size:19px;color:${BRAND.ink};">${escapeHtml(title)}</h1>
        <div style="font-size:14px;line-height:1.6;color:${BRAND.ink};margin-top:14px;">
          ${bodyHtml}
        </div>
        ${pillButton(ctaLabel, ctaUrl)}
      </td></tr>
      <tr><td style="padding:20px 32px;background:${BRAND.card};border-top:1px solid ${BRAND.border};">
        <p style="margin:0 0 6px;font-size:12px;color:${BRAND.muted};">Need help? Contact <a href="mailto:${BRAND.supportEmail}" style="color:${BRAND.primary};text-decoration:none;">${BRAND.supportEmail}</a></p>
        <p style="margin:0;font-size:11px;color:${BRAND.mutedLight};">This is an automated message from ${BRAND.name} — please don't reply directly to this email.</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

module.exports = {
  BRAND, escapeHtml, detailRow, detailsCard, calloutBox, pillButton, referenceLine, wrapEmail,
};
