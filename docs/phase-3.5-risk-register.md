# Phase 3.5 Risk Register

| Risk | Likelihood / impact | Mitigation | Gate |
|---|---|---|---|
| Hosted CI differs from local execution | Medium / High | Require green application, database and browser jobs on the exact candidate | UAT |
| Real Storage bytes are not in the local restore sample | Medium / High | Export, hash, restore and authorize representative private objects | Pilot |
| No human Arabic screen-reader session | Medium / Medium | NVDA/VoiceOver UAT with recorded issues and sign-off | Pilot |
| Monitoring destinations and on-call ownership unset | High / High | Configure alerts, test delivery and escalation | Pilot |
| Import fixture volume is small | Medium / High | Rehearse approved full-volume sanitized files and reconcile signed totals | Parallel run |
| Staging rollback not executed | Medium / High | Deploy two immutable artifacts and rehearse frontend rollback plus forward DB repair | Pilot |
| Local repository path contains literal `~` | Low / Low | Use clean-path harness or normal CI checkout for Vitest | Accepted |
| Human financial UAT not signed | High / Critical | Named finance/owner reviewers execute monthly close and reporting reconciliation | Parallel run |

No listed risk blocks creation of staging. None may be silently accepted for go-live.
