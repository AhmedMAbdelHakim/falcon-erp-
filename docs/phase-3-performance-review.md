# Phase 3 Performance Review

Final production build on 2026-07-15 transformed 1,881 modules in 894 ms. Output: HTML 0.59 kB (0.37 gzip), CSS 52.05 kB (10.89 gzip), JS 683.90 kB (183.89 gzip).

Resource pages request 25 rows with server-side count, search, organization filter, and range. Journal/audit reads are capped at 100; close history at 36. Dashboard and the three financial reports use aggregate RPCs, not raw ledger downloads.

The build reports a non-failing chunk-size advisory above 500 kB. Before production, split legacy printing/barcode routes and heavy report modules, record route Web Vitals in staging, and inspect query plans for real staging volumes. No slow route or query claim is made without staging telemetry.
