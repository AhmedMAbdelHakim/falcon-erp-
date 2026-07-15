# Environment Matrix

| Environment | Data | Auth | Deployment | Status |
|---|---|---|---|---|
| Local | Synthetic only; local Docker Supabase | Synthetic local users | Vite dev/preview | Verified |
| CI | Fresh migrations and deterministic tests | Test fixtures | GitHub Actions runners | Workflow defined; remote run not observed |
| Staging | Sanitized synthetic/UAT dataset only | Named test users and role matrix | Requires separate authorization | Not provisioned |
| Production | Real data after approved import | Real users with reviewed assignments | Separate explicit approval | Not authorized |

Browser variables are `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. Only a public publishable/anon key may be exposed. Environment labels must remain visibly distinct.
