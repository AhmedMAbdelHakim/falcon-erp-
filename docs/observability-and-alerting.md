# Observability and Alerting

Correlate frontend failures, RPC envelopes, command executions, journal entries, and audit events by `correlation_id`. Do not log secrets, raw evidence, full customer addresses, payroll values outside authorized channels, or provider credentials.

Staging alerts should cover repeated authorization denial, RPC error-rate spikes, duplicate-fingerprint conflicts, close/post lock violations, unbalanced-posting attempts, negative inventory, unposted events, stale wallet reconciliation, pending approvals, failed imports, and backup failures.

Dashboards should report latency percentiles by RPC, error code, database connection pressure, slow queries, auth failures, and frontend asset errors. Alert owners and escalation windows must be assigned before UAT. No external monitoring destination was configured in this phase.
