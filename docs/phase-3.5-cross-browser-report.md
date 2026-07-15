# Phase 3.5 Cross-Browser Report

Command: `npm run test:e2e:cross-browser`  
Result: 15 passed, 6 intentional performance-test skips, 0 failed, 2.1 minutes.

| Profile | Engine/device | Theme/input mode | Result |
|---|---|---|---|
| chromium-desktop-dark | Chromium 149, 1440x900 | Dark | PASS |
| firefox-desktop-light | Firefox 151, 1440x900 | Light | PASS |
| webkit-desktop-dark | WebKit 26.5, 1440x900 | Dark | PASS |
| chromium-tablet-light | Chromium, 1024x768 | Light | PASS |
| chromium-mobile-portrait | Pixel 5, 390x844 | Dark, portrait | PASS |
| chromium-mobile-landscape | Pixel 5, 844x390 | Light, landscape | PASS |
| chromium-high-contrast | Chromium, 1440x900 | Forced colors, reduced motion | PASS |

Each profile covered 17 major routes, RTL, overflow, dialog accessibility, authorization denial, cross-organization isolation, logout and expired-session redirect. Dashboard and order-dialog screenshots are under the Playwright `test-results/screenshots` artifact directory.
