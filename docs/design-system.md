# Design System

Falcon uses a dense operational interface: charcoal navigation, neutral surfaces, orange command accent, teal success, amber warning, and red destructive states. Cards and controls use radii of 8px or less.

CSS variables in `src/index.css` define light and dark themes. Theme preference supports light, dark, and system modes. Core patterns are page headers, toolbars, data tables, KPI blocks, metadata bars, status badges, dialogs, and explicit loading/empty/error/denied states.

Icons come from Lucide. Icon-only controls have Arabic accessible names and tooltips. Money is tabular, isolated LTR within RTL text, and formatted from signed `bigint` minor units. Breakpoints at 1100, 820, and 520 pixels preserve table scrolling, drawer navigation, and single-column command forms.
