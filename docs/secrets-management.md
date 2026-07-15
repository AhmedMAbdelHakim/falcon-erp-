# Secrets Management

- `.env` and `.env.*` are ignored; `.env.example` contains public placeholders only.
- Service-role keys, database passwords, JWT signing secrets, and provider credentials must be stored in the approved CI/hosting secret store and never bundled into Vite.
- Suspected exposure requires immediate revocation, rotation, history review, and incident logging.
- CI should run a dedicated secret scanner before merge. The local pattern scan reported no current working-tree key-shaped values.
- Supabase Storage evidence buckets remain private; clients receive only short-lived authorized access.
- Production access should use least-privilege operators and logged break-glass procedures.
