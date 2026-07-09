/**
 * One renderer per email family, each returning { subject, html }. Several
 * SecureBank event types share a renderer (parameterized by `templateData`)
 * rather than each getting a near-duplicate file — e.g. cash-in/cash-out/
 * transfer all render through `transactionReceipt`, and password-changed/
 * new-device-login/google-sign-in all render through `securityAlert`.
 */
const {
  BRAND, escapeHtml, detailRow, detailsCard, calloutBox, referenceLine, wrapEmail,
} = require('./layout');

const now = () => new Date();
const fmtDateTime = (iso) => {
  const d = iso ? new Date(iso) : now();
  return d.toLocaleString('en-GB', {
    day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  });
};
const fmtFcfa = (n) => `${Number(n || 0).toLocaleString('en-US')} FCFA`;
const greet = (name) => `Hi ${escapeHtml(name || 'there')},`;

const SECURITY_ADVICE =
  'If you don’t recognise this activity, secure your account immediately: change your password and contact support.';

// ---------------- Account lifecycle ----------------

function accountCreated({ name }) {
  return {
    subject: `Welcome to ${BRAND.name}`,
    html: wrapEmail({
      title: `Welcome to ${BRAND.name}, ${name || 'there'}!`,
      preheader: 'Your account is ready.',
      bodyHtml: `<p>${greet(name)}</p>
        <p>Your ${BRAND.name} account has been created successfully. You're all set to manage your accounts, track spending, and stay protected by our fraud detection engine.</p>
        ${calloutBox('For your security, never share your password or one-time codes with anyone — SecureBank staff will never ask for them.', { icon: '🔒' })}`,
    }),
  };
}

function securityAlert({ name, event, deviceInfo, location, time }) {
  const titles = {
    password_changed: 'Your password was changed',
    google_sign_in: 'Signed in with Google',
    new_device_login: 'New device sign-in detected',
    password_reset: 'Your password was reset',
  };
  const title = titles[event] || 'Security notice';
  return {
    subject: `${BRAND.name} security alert: ${title}`,
    html: wrapEmail({
      title,
      preheader: title,
      accent: BRAND.danger,
      bodyHtml: `<p>${greet(name)}</p>
        <p>${title} on your ${BRAND.name} account.</p>
        ${detailsCard([
          detailRow('Time', fmtDateTime(time)),
          deviceInfo ? detailRow('Device', deviceInfo) : '',
          location ? detailRow('Location', location) : '',
        ].filter(Boolean))}
        ${calloutBox(SECURITY_ADVICE, { color: BRAND.danger, icon: '⚠️' })}`,
    }),
  };
}

function accountStatus({ name, suspended, reason }) {
  return {
    subject: suspended
      ? `Your ${BRAND.name} account has been suspended`
      : `Your ${BRAND.name} account has been reactivated`,
    html: wrapEmail({
      title: suspended ? 'Account Suspended' : 'Account Reactivated',
      accent: suspended ? BRAND.danger : BRAND.success,
      bodyHtml: `<p>${greet(name)}</p>
        <p>${suspended
          ? 'Your account has been suspended by a SecureBank administrator.'
          : 'Your account has been reactivated and you now have full access again.'}</p>
        ${reason ? detailsCard([detailRow('Reason', reason)]) : ''}
        ${suspended
          ? calloutBox('If you believe this is a mistake, contact support for assistance.', { color: BRAND.danger, icon: '⛔' })
          : ''}`,
    }),
  };
}

// ---------------- Transactions ----------------

function transactionReceipt({ name, type, amount, category, merchant, account, referenceNumber, time }) {
  const labels = { cash_in: 'Cash In', cash_out: 'Cash Out', transfer: 'Transfer' };
  const label = labels[type] || 'Transaction';
  return {
    subject: `${BRAND.name} receipt: ${label} of ${fmtFcfa(amount)}`,
    html: wrapEmail({
      title: `${label} Confirmed`,
      preheader: `${label} of ${fmtFcfa(amount)}`,
      accent: BRAND.success,
      bodyHtml: `<p>${greet(name)}</p>
        <p>This confirms your ${label.toLowerCase()} of <strong>${fmtFcfa(amount)}</strong>.</p>
        ${detailsCard([
          detailRow('Amount', fmtFcfa(amount)),
          category ? detailRow('Category', category) : '',
          merchant ? detailRow('Merchant', merchant) : '',
          account ? detailRow('Account', account) : '',
          detailRow('Date', fmtDateTime(time)),
        ].filter(Boolean))}
        ${referenceLine(referenceNumber)}`,
    }),
  };
}

// ---------------- Budget ----------------

function budgetReminder({ name, budgetName, category, spent, limit, percentUsed }) {
  return {
    subject: `${BRAND.name}: budget alert for ${budgetName || category}`,
    html: wrapEmail({
      title: 'Budget Limit Reached',
      accent: BRAND.warning,
      bodyHtml: `<p>${greet(name)}</p>
        <p>Your <strong>${escapeHtml(budgetName || category)}</strong> budget has reached ${percentUsed}% of its limit.</p>
        ${detailsCard([
          detailRow('Spent', fmtFcfa(spent)),
          detailRow('Budget limit', fmtFcfa(limit)),
          detailRow('Usage', `${percentUsed}%`),
        ])}
        ${calloutBox('Review your spending in the app to stay on track for the rest of the period.', { color: BRAND.warning, icon: '📊' })}`,
    }),
  };
}

// ---------------- Fraud ----------------

function fraudAlert({ name, riskLevel, riskScore, reason, amount, time, referenceNumber }) {
  return {
    subject: `${BRAND.name} fraud alert: ${riskLevel} risk transaction detected`,
    html: wrapEmail({
      title: `${riskLevel} Risk Transaction Detected`,
      preheader: reason,
      accent: BRAND.danger,
      bodyHtml: `<p>${greet(name)}</p>
        <p>Our fraud detection engine flagged a transaction on your account as <strong>${riskLevel} risk</strong> and it is pending your review.</p>
        ${detailsCard([
          amount ? detailRow('Amount', fmtFcfa(amount)) : '',
          detailRow('Risk level', riskLevel),
          detailRow('Risk score', String(riskScore ?? '')),
          detailRow('Reason', reason || ''),
          detailRow('Detected', fmtDateTime(time)),
        ].filter(Boolean))}
        ${calloutBox('Open the SecureBank app to Approve or Decline this transaction from your Notifications inbox.', { color: BRAND.danger, icon: '🚨' })}
        ${referenceLine(referenceNumber)}`,
    }),
  };
}

function fraudResolution({ name, approved, amount, referenceNumber, time }) {
  return {
    subject: approved
      ? `${BRAND.name}: transaction approved`
      : `${BRAND.name}: transaction blocked for your protection`,
    html: wrapEmail({
      title: approved ? 'Transaction Approved' : 'Transaction Blocked',
      accent: approved ? BRAND.success : BRAND.danger,
      bodyHtml: `<p>${greet(name)}</p>
        <p>${approved
          ? 'You approved the flagged transaction below — it has been processed normally.'
          : 'You declined the flagged transaction below — it has been blocked and will not affect your balance.'}</p>
        ${detailsCard([
          amount ? detailRow('Amount', fmtFcfa(amount)) : '',
          detailRow('Decision time', fmtDateTime(time)),
        ].filter(Boolean))}
        ${referenceLine(referenceNumber)}`,
    }),
  };
}

// ---------------- KYC ----------------

function kycStatus({ name, approved, notes }) {
  return {
    subject: approved
      ? `${BRAND.name}: your identity verification was approved`
      : `${BRAND.name}: your identity verification needs attention`,
    html: wrapEmail({
      title: approved ? 'KYC Verification Approved' : 'KYC Verification Update',
      accent: approved ? BRAND.success : BRAND.warning,
      bodyHtml: `<p>${greet(name)}</p>
        <p>${approved
          ? 'Your identity verification (KYC) has been approved. You now have full access to all SecureBank features.'
          : 'Your identity verification (KYC) submission requires attention. Please review the details below and resubmit from the app.'}</p>
        ${notes ? detailsCard([detailRow('Reviewer notes', notes)]) : ''}`,
    }),
  };
}

// ---------------- Admin ----------------

function adminAnnouncement({ name, title, body, priority }) {
  return {
    subject: `${BRAND.name}: ${title}`,
    html: wrapEmail({
      title,
      accent: priority === 'critical' ? BRAND.danger : BRAND.primary,
      bodyHtml: `<p>${greet(name)}</p><p>${escapeHtml(body)}</p>`,
    }),
  };
}

// ---------------- Monthly summary ----------------

function monthlySummary({
  name, month, totalIncome, totalExpense, savings, topCategory,
  fraudAlertsCount, budgetPerformancePct, securityScore, tip,
}) {
  return {
    subject: `${BRAND.name}: your ${month} financial summary`,
    html: wrapEmail({
      title: `Your ${month} Summary`,
      accent: BRAND.primary,
      bodyHtml: `<p>${greet(name)}</p>
        <p>Here's how your finances looked in ${month}.</p>
        ${detailsCard([
          detailRow('Total income', fmtFcfa(totalIncome)),
          detailRow('Total expenses', fmtFcfa(totalExpense)),
          detailRow('Savings', fmtFcfa(savings)),
          topCategory ? detailRow('Highest spending category', topCategory) : '',
          detailRow('Fraud alerts', String(fraudAlertsCount ?? 0)),
          detailRow('Budget performance', `${budgetPerformancePct ?? 0}%`),
          detailRow('Security score', `${securityScore ?? 0}/100`),
        ].filter(Boolean))}
        ${tip ? calloutBox(tip, { icon: '💡' }) : ''}`,
    }),
  };
}

/** eventType -> renderer. Several event types share one renderer. */
const RENDERERS = {
  account_created: accountCreated,
  google_sign_in: (d) => securityAlert({ ...d, event: 'google_sign_in' }),
  password_changed: (d) => securityAlert({ ...d, event: 'password_changed' }),
  password_reset: (d) => securityAlert({ ...d, event: 'password_reset' }),
  new_device_login: (d) => securityAlert({ ...d, event: 'new_device_login' }),
  security_alert: (d) => securityAlert({ ...d, event: d.event || 'new_device_login' }),
  account_suspended: (d) => accountStatus({ ...d, suspended: true }),
  account_reactivated: (d) => accountStatus({ ...d, suspended: false }),
  cash_in: (d) => transactionReceipt({ ...d, type: 'cash_in' }),
  cash_out: (d) => transactionReceipt({ ...d, type: 'cash_out' }),
  transfer: (d) => transactionReceipt({ ...d, type: 'transfer' }),
  budget_exceeded: budgetReminder,
  fraud_detected: fraudAlert,
  fraud_approved: (d) => fraudResolution({ ...d, approved: true }),
  fraud_declined: (d) => fraudResolution({ ...d, approved: false }),
  kyc_approved: (d) => kycStatus({ ...d, approved: true }),
  kyc_rejected: (d) => kycStatus({ ...d, approved: false }),
  admin_announcement: adminAnnouncement,
  monthly_summary: monthlySummary,
};

module.exports = { RENDERERS };
