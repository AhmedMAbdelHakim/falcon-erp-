# Legacy Shipping Compatibility Inventory

Status: IMPLEMENTED, runtime verification pending.

The historical `supabase/schema.sql` is not part of the migration chain and must
not be executed. Migration `20260714162241_legacy_shipping_compatibility.sql`
replaces its application contract with organization-scoped objects.

| Legacy object | Consumer | Compatibility decision | Security decision |
|---|---|---|---|
| `public.profiles.full_name` | `AuthContext` | Generated from `display_name` | Read through existing profile RLS |
| `public.profiles.role` | Sidebar/settings presentation | Derived `admin`/`staff` label retained | Never used for authorization; synchronized from database RBAC |
| `public.labels` | Dashboard, create/edit/list/cancel/print/export | Recreated with all consumed columns and states | Organization FK/default, capability RLS, immutable owner/scope |
| `public.shipping_settings` | Create label, batch print, settings | Recreated as organization-keyed JSON settings | Read/manage capabilities |
| `public.governorate_shipping_fees` | Create/list/settings | Recreated with per-organization uniqueness | Read/manage capabilities |
| `public.handle_updated_at` | Historical triggers only | Retired | Replaced by `private.set_updated_at` |
| `public.handle_new_user` | Historical auth trigger | Retired | Metadata-derived organization/role creation is prohibited |
| `public.check_profile_update` | Historical role guard | Retired | Compatibility role is derived; authoritative RBAC stays private |
| `public.get_my_role` | Historical policies | Retired | Replaced by `private.has_permission` |
| historical broad policies | All legacy tables | Retired | Explicit organization and capability predicates |
| default governorate rows | Settings | Preserved through `supabase/seed.sql` | Seeded per reference organization |
| `store_config` | Settings | Preserved through `supabase/seed.sql` | Seeded per reference organization |

No storage bucket, view, RPC, or additional legacy table was found in
`supabase/schema.sql` or in the application query surface. The app performs
direct PostgREST CRUD only; it does not call a legacy RPC.

## Data Preservation

The repository has no deployed database dump to migrate. For a live legacy
database, use the preflight and copy steps in `migration-and-rollback-plan.md`.
Do not apply the fresh-database compatibility migration directly over legacy
tables with the same names.

