# Backup Guide

For local verification run `npm run test:backup`; it creates a full custom-format logical dump and performs an isolated restore. For staging/production, use the approved platform backup plus a separate private Storage object export.

Record environment, timestamp, migration head, Postgres version, dump SHA-256, object manifest/checksums, encryption location, retention class and operator. Verify the artifact is non-empty and access-restricted. A backup is not accepted until a restore drill proves it.
