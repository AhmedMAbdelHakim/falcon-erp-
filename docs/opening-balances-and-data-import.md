# Opening Balances and Data Import

Imports must be staged, validated, approved, and posted through dedicated commands; never insert journals or financial events directly.

Required templates: chart/account mapping, customers, suppliers, products/variants, inventory by location and unit cost, wallet physical balances, supplier/customer open items, partner capital/current accounts, loans, payroll opening liabilities, and document references. Money uses integer EGP minor units and every source row carries a stable external key.

Dry run checks include duplicate keys, referential integrity, normalized phones, balanced opening journal, inventory conservation, control-account reconciliation, wallet reconciliation, and totals signed by the financial reviewer. Re-run with the same import idempotency keys must replay safely. No data import or opening balance dry run was performed because approved source data and staging are not available.
