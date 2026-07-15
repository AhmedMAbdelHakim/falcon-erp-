# Phase 3.5 Playwright Report

The final matrix ran 21 scheduled cases: 15 passed and 6 performance duplicates were intentionally skipped outside desktop Chromium. There were no failures.

The route scenario validates login, Dashboard, Orders, Payments, Printing, Inventory, Shipping, Settlements, Expenses, Payroll, Partners, Ledger, Reports, Monthly Close, Wallets, Settings, Approvals and Audit. Every route must show its Arabic heading, retain RTL direction and avoid document-level horizontal overflow.

The authorization scenario proves moderator denial for Ledger, sandbox organization context, zero cross-organization Orders, logout and protected-route redirect after session removal. Synthetic fixture loading is a single SQL transaction and uses supported Auth/profile provisioning.

The accessibility scenario checks the order command dialog, keyboard focus containment and an axe scan including contrast. Final local performance attachment recorded 88 ms initial load and 154 ms route transition.
