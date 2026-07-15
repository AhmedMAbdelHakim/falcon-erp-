# Frontend Architecture

Falcon remains a Vite, React 19, TypeScript, React Router, and Supabase application.

- `src/context/AuthContext.tsx`: session plus authoritative `api.read_current_access_context`; permission checks never use user metadata.
- `src/components/AppShell.tsx`: Arabic RTL navigation filtered by effective permission keys.
- `src/features/resources/catalog.ts`: declarative read-only operational modules.
- `src/server/queries/`: typed browser-to-Data-API reads. The name reflects the query boundary; no privileged server secret is present.
- `src/features/workflows/actions.ts` and `WorkflowActions.tsx`: closed RPC action catalog, server-generated canonical fingerprints, unique idempotency and correlation identifiers.
- Financial reports use verified `api` read RPCs. Operational lists use RLS-protected tables or `security_invoker` views.
- Legacy labels remain under `/legacy/*`; they cannot post accounting records.

The browser has only the public Supabase key. RLS and each RPC re-authorize the current database assignments, so route hiding is usability rather than the security boundary.
