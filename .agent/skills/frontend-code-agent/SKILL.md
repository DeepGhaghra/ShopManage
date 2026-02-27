---
name: building-frontend-screens
description: Implements Flutter UI screens and widgets for the Sales App project. Use when the user asks to build, modify, or fix a screen, widget, form, list, dialog, or navigation flow in any module including Dashboard, Stock View, Sales Entry, Purchase, Party management, Price List, Export Data, Payment Reminders, or Party Sales Target.
---

# Frontend Code Agent — Laminates Wholesaler Management App

## When to use this skill
- User asks to build or update a Flutter screen/widget
- User wants a new form, list, card, dialog, or bottom sheet
- User needs to implement Dashboard metrics (Today’s Sales, Trending, Low Stock)
- User asks to implement/fix the multi-item Sales Entry form
- User wants to add printer support or preview for Challans

## Project Context
- **Framework:** Flutter (Dart ^3.7.0), Material Design
- **State management:** GetX for reactive updates and dependency injection
- **Design Philosophy:** Clean, fast data entry, minimal clicks workflow
- **Key Screens:** 
  - **Dashboard:** Grid/Metric-based layout with Today's Count, Top Design, Low Stock.
  - **Sales Entry:** Form with searchable Party/Design dropdowns, multi-item table/list, auto-calculated rates.
  - **Stock View:** Data table for inventory, Add/Transfer dialogs.
  - **Print Preview:** Previewing challans before sending to Wi-Fi/Thermal printer.

## Workflow

- [ ] Identify the module folder: `lib/ui/` or `lib/app/modules/`
- [ ] Determine if the widget needs `Obx` for real-time stock/rate updates
- [ ] Check if `SearchableDropdown` is required for Parties or Design numbers
- [ ] Implement responsive layout (breakpoints for phone vs. tablet)
- [ ] Add loading/empty/error states for data-heavy views (Stock/Sales List)
- [ ] Verify form validation (e.g., qty > 0, party selected)

## Instructions

### Dashboard Metrics Widget
```dart
Widget _buildMetricCard(String title, String value, IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
}
```

### Multi-Item Entry List (Sales Module)
Use a `ListView` or dynamic `Column` inside the form to allow users to add multiple design entries (Design No, Qty, Rate).
```dart
// Reactive list of items in Controller
final items = <SalesItem>[].obs;

// In View
Obx(() => Column(
  children: controller.items.map((item) => _buildItemRow(item)).toList(),
))
```

### Common Components
- **Parties/Designs Selection:** Always use a searchable dropdown to handle large datasets.
- **Stock View Table:** Use `PaginatedDataTable` or a customized `ListView` with a header row for large inventory lists.

### Rules
- **Responsive:** Dashboard is 3 cols on phone, 5 on tablet.
- **User Flow:** Minimize keyboard switching for rapid entry in Sales/Purchase modules.
- **Feedback:** Use `SnackbarUtil` for save confirmations or stock errors (e.g., "Insufficient Stock").

## Resources
- Main Entry: `lib/main.dart`
- Routes: `lib/routing/router.dart`
- Auth screens: `lib/ui/auth/`
- Home screen: `lib/ui/home/`
- Stock screens: `lib/ui/stock/`
