---
name: designing-ui-ux
description: Guides UI/UX design decisions for the Sales App Flutter project. Use when the user asks about screen layouts, component design, color schemes, navigation flows, widget choices, responsive design, or user experience improvements across any module such as Dashboard, Stock View, Sales Entry, or Party management screens.
---

# UI/UX Design Agent — Laminates Wholesaler Management App

## When to use this skill
- User asks for layout improvements for the Sales Entry form
- User wants to design the Dashboard metrics (Today’s Sales, Trending)
- User asks about the responsive behavior of the Stock table
- User wants to optimize for "clean, fast data entry" and "minimal clicks"

## Project Context
- **Framework:** Flutter Material Design
- **Design Philosophy (PRD §12):** 
  - Clean, fast data entry screens.
  - Dropdown search for Parties and Design numbers.
  - Minimal clicks workflow.
  - Responsive layout (optimized for Phone/Tablet).
- **Core Components:** `SearchableDropdown`, `MetricCard`, `BaseScreen`.
- **Navigation Standards (Sub-pages):** 
  - Sub-pages (Sales, Purchase, Stock, etc.) must have BOTH a **Back Button** and a **Menu Icon** grouped together on the left side of the AppBar.
  - This is implemented using `leadingWidth: 96` and a `Row` in the `leading` property.
  - Root pages (Dashboard) only have the Hamburger Menu icon.

## Workflow

- [ ] Identify the user role (Admin vs. Normal) to determine navigation options
- [ ] For non-root screens, ensure `leadingWidth: 96` with Back + Menu icons
- [ ] Design forms (Sales/Purchase) to minimize field-to-field transitions
- [ ] Ensure all critical metrics on the Dashboard are clickable to view datasets
- [ ] Use `SearchableDropdown` for entity selection to handle large data efficiently
- [ ] Implement a **Print Preview** modal before triggering ESC/POS printing

## Instructions

### Dashboard Design (PRD §6)
- Top of the home screen: 3 large metric cards (Count, Trending, Low Stock).
- Each card must be visually distinct with clear labels and values.

### Form Design Standards (PRD §12)
- Use `keyboardType: TextInputType.number` for Qty and Rate.
- Use `Autofocus` where appropriate for faster entry.
- Multi-item entry: Use rows in a scrollable list with a "Add Item" button.

### Responsive Breakpoints
- **Mobile (< 600px wide):** Single column forms, stacked layout for metrics.
- **Tablet (≥ 600px wide):** Multi-column dashboard grid, side-by-side form fields (e.g., Party selection beside Date).

### Rules
- **Dropdowns:** Never use a standard `DropdownButton` if the list of Parties or Designs is expected to exceed 10 items; use `SearchableDropdown`.
- **Feedback:** Provide immediate visual confirmation (Success Snackbar) on Save/Print.

## Resources
- Colors: `lib/app/core/utils/app_colors.dart`
- Shared Widgets: `lib/app/core/common/`
- Home Screen: `lib/ui/home/home_screen.dart`
