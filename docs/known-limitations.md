# Known Limitations

- No authorized hosted staging environment or hosted CI run has been executed.
- Human Arabic screen-reader, 200% zoom and native OS high-contrast sessions remain staging UAT work.
- Local restore contained zero Storage objects, so object-byte export/re-upload is not yet evidenced.
- Monitoring destinations, on-call roster and alert delivery are not configured here.
- Import fixtures prove validation behavior at small synthetic volume, not production-scale throughput.
- Local timing is a regression sample, not a public-network SLA.
- Vitest cannot resolve modules from this machine's literal `~` repository path; the clean-path QA harness passes.
- Search remains visibly disabled by the current product contract; no new search feature was added.
