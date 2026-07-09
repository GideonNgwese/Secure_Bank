# SecureBank — Flutter + Firebase Starter

A fraud-aware personal finance aggregation prototype, scaffolded to match the
SecureBank B-Tech Development Guide (bank/mobile-money account profiles,
manual transaction entry, dashboard, budgeting, rule-based fraud-risk
scoring, and a simple admin panel). **No real bank accounts are accessed and
no real money moves** — everything is simulated with user-entered records,
exactly as the guide recommends.

## 1. What's included

```
lib/
  main.dart                    App entry point + auth routing
  firebase_options.dart        PLACEHOLDER — replace via flutterfire configure
  models/                      User, Account, Transaction, Budget, Alert
  services/
    auth_service.dart          Register / login / logout / profile lookup
    firestore_service.dart     Accounts, transactions, transfers, budgets, alerts, admin
    fraud_service.dart         Rule-based fraud-risk scoring engine
  screens/
    auth/                      Login, Register
    home/                      Role-based routing + bottom nav shell
    dashboard/                 Consolidated balance, income/expense, spending chart
    accounts/                  Account list + add account
    transactions/              Transaction list (filter/search) + add transaction/transfer
    budget/                    Set budgets, usage bars, warnings
    alerts/                    Fraud + budget alert feed
    admin/                     Admin overview, user management, flagged transactions
firestore.rules                Security rules (users only see their own data; admin sees all)
sample_data/sample_transactions.csv   Sample file for the optional CSV-import feature
```

This covers the **minimum version** from the guide: auth + roles, account
profiles, transaction recording, calculated dashboard, budgets with
warnings, fraud-risk scoring, and an admin dashboard with flagged
transactions and user suspension.

**Not yet built (optional/"if time remains" in the guide):** CSV import
parsing screen, PDF/Excel report export, KYC document upload UI, email
notifications. The `kyc_documents` and `activity_logs` structures are
already in the security rules so you can add these later without
re-architecting anything.

## 2. Set up Firebase (do this first)

1. Go to https://console.firebase.google.com and create a new project.
2. In **Build → Authentication → Sign-in method**, enable **Email/Password**.
3. In **Build → Firestore Database**, create a database (start in **test
   mode** for development — lock it down with `firestore.rules` before any
   real demo/defense).
4. Install the FlutterFire CLI and connect this project to your Firebase
   project:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Select your Firebase project and the platforms you need (Android/iOS/Web).
   This **overwrites** `lib/firebase_options.dart` with your real keys —
   that's expected, the one in this scaffold is just a placeholder.
5. Deploy the security rules (requires the Firebase CLI: `npm install -g
   firebase-tools`):
   ```bash
   firebase login
   firebase init firestore   # point it at this folder, use existing firestore.rules
   firebase deploy --only firestore:rules
   ```

## 3. Install dependencies & run

```bash
flutter pub get
flutter run
```

Register a normal account from the app — it will be created with
`role: customer`. To test the **admin dashboard**, open Firestore in the
Firebase console, find that user's document under `users/{uid}`, and change
`role` from `customer` to `admin`, then log back into the app.

## 4. How the core logic maps to the guide

- **Balance calculation** (`firestore_service.dart ->
  calculateAccountBalance`): `opening balance + income − expenses +
  transfers in − transfers out`, recalculated live from stored transactions
  — never manually typed after the first entry.
- **Transfers** (`addTransfer`): creates two linked transaction records
  (transfer-out / transfer-in) instead of moving real money.
- **Fraud-risk scoring** (`fraud_service.dart`): implements all six rules
  from the guide (large amount, amount vs. user average, transaction
  velocity, odd hours, duplicate amount+description, simulated new-device
  flag) and buckets the total score into Low / Medium / High exactly as
  specified (0–30 / 31–60 / 61–100).
- **Budget warnings** (`checkBudgetAfterTransaction`): fires an alert at
  ≥80% (almost exceeded) and ≥100% (exceeded) of a category's monthly
  limit, matching the guide's thresholds.
- **Admin screens**: user list with suspend/reactivate, and a flagged
  transactions feed pulling every Medium/High risk transaction system-wide.

## 5. Suggested next steps (in priority order, per the guide's Section 10)

1. Get login/register + role-based routing working end-to-end (done here).
2. Confirm account profile + transaction CRUD against your own test data.
3. Wire up the dashboard and budget screens with real transactions.
4. Add the CSV import screen using the `csv` package already in
   `pubspec.yaml` (parse `sample_data/sample_transactions.csv`, preview,
   dedupe, then call `addTransaction` per row).
5. Add PDF/Excel export for the Reports screen if time allows.
6. Take screenshots of every working screen for Chapter Four/Five — the
   guide is explicit that screenshots must match what's actually built.

## 6. Defense reminder (from the guide)

Be upfront that this is an academic prototype: no live bank/mobile money
API integration, no real fund movement, and fraud detection is rule-based
scoring rather than trained AI. That framing is what makes the project
defendable — a smaller, fully working system beats a larger one with
claims that can't be demonstrated.
