---
name: managing-analytics
description: Implements usage tracking, business analytics, and sales reporting for the Sales App Flutter project. Use when the user asks about tracking user actions, generating sales reports, visualizing data (charts/graphs), measuring feature usage, building dashboards with KPIs, or analyzing party-wise or product-wise sales trends.
---

# Analytics Agent — Laminates Wholesaler Management App

## When to use this skill
- User wants to add charts or metrics to the Dashboard
- User asks about Today’s Total Sales, Trending Designs, or Low Stock alerts
- User needs to implement or modify the Export Data module (Excel/PDF)
- User asks for reports on sales trends or inventory status

## Project Context
- **Key Metrics (PRD §6):**
  - **Today’s Total Sales Count:** Count of sales invoices generated today.
  - **Top Trending Design Number:** Design with the highest sales frequency today.
  - **Low Stock Design List:** List of designs where total quantity < 10.
- **Data Source:** Supabase tables (`sales`, `sales_items`, `stock`).
- **Export Formats:** Excel and PDF (filtered by Date Range and Module Type).

## Workflow

- [ ] Define the specific aggregate query needed for the KPI
- [ ] **Crucial:** Always filter by `shop_id` for all analytics queries
- [ ] Implement the repository method to fetch aggregate data
- [ ] Use `Obx` in the Dashboard view to reflect real-time changes
- [ ] For "Trending" designs, calculate frequency in the current date range

## Instructions

### Dashboard KPI Queries

**Today's Sales Count**
```dart
final count = await client
  .from('sales')
  .count()
  .eq('shop_id', shopId)
  .gte('created_at', todayStart.toIso8601String());
```

**Top Trending Design (Top frequency today)**
```dart
// Fetch sales_items for today, then aggregate in Dart
final items = await client
  .from('sales_items')
  .select('design_no')
  .eq('shop_id', shopId)
  .gte('created_at', todayStart.toIso8601String());

// Logic to find the mode of design_no in the list
```

**Low Stock List**
```dart
final lowStock = await client
  .from('stock')
  .select('design_no, quantity, location')
  .eq('shop_id', shopId)
  .lt('quantity', 10); // PRD default threshold: < 10
```

### Export Module Requirements (PRD §7.6)
- **Filters:** Date Range (Start/End), Module Type (Sales, Purchase, Stock).
- **Excel:** Use the `excel` package to generate sheets.
- **PDF:** Use the `pdf` package for tabular reports.

### Rules
- **Shop Scoping:** Never show analytics data from one shop to a user in another shop.
- **Performance:** For large datasets, use Supabase aggregate functions or cached total counts.

## Resources
- Dashboard View: `lib/ui/home/home_screen.dart`
- Dashboard Controller: `lib/services/dashboard_providers.dart` (or similar)
- Export Module: `lib/ui/export/` (implement if missing)
