# Staging Deployment Guide

1. Create a separate Supabase project and frontend environment using synthetic or approved sanitized data only.
2. Configure public browser variables and store all privileged values in the approved secret store.
3. Apply the 55 migrations from zero and seed only synthetic reference data.
4. Regenerate database types; require no diff against the candidate.
5. Run database lint, 351 pgTAP assertions, concurrency, app QA and the seven-profile Playwright matrix.
6. Configure private Storage buckets, upload representative synthetic files and test authorized/denied reads.
7. Deploy the immutable frontend candidate, test alert delivery and execute the UAT package.
8. Record artifacts, timestamps, outputs and reviewer sign-off. Never reuse production credentials or data.
