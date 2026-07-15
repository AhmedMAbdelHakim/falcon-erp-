# Phase 3.5 Backup and Restore Report

Command: `npm run test:backup`  
Result: PASS.

The script created a full custom-format logical dump from local Supabase, copied it to `test-results/backup`, restored it into `falcon_phase35_restore`, and compared source/restore counts. It then removed the temporary database and verified its count was zero.

| Evidence | Value |
|---|---|
| Artifact size | 1,920,600 bytes |
| SHA-256 | `fcebac3196bcacea2dae819ca8aaf69ce23aef34cd3a986b6f60206aa6a5effd` |
| Measured local RTO | 5.52 seconds |
| Organizations / accounts | 1 / 33 in source and restore |
| Journal entries / lines | 1 / 2 in source and restore |
| Unbalanced entries | 0 in source and restore |
| Storage objects | 0 in source and restore |

The measured RPO is the dump start time; no continuous recovery claim is made. The test validates Storage metadata only because the local source had zero object bytes. Staging must add object export/download, checksum and re-upload validation before pilot approval.
