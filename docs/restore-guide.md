# Restore Guide

1. Create an isolated target; never overwrite the source during a drill.
2. Verify backup/object-manifest hashes and target Postgres/Supabase compatibility.
3. Restore database roles/config as approved, then the database dump, then private object bytes.
4. Compare critical table counts, migration head and object checksums.
5. Prove every journal balances, closed periods remain closed, attachments resolve and representative roles obey RLS.
6. Run lint, pgTAP, concurrency, generated types and browser authorization tests.
7. Record RPO/RTO, differences and reviewer decision; remove the temporary target after evidence retention.
