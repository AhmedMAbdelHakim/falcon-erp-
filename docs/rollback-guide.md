# Rollback Guide

Frontend rollback selects the previous immutable artifact after confirming it is schema-compatible. Applied database migrations are never edited or deleted; correct defects with a reviewed forward migration. If data correctness is uncertain, disable affected commands and restore the backup into an isolated environment for reconciliation before deciding any source-environment action.

Every rehearsal records trigger, decision owner, artifact/migration identities, start/end time, validation output and residual risk. A remote reset, destructive history rewrite or undocumented table edit is prohibited.
