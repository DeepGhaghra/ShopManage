---
name: managing-integrations
description: Handles third-party service integrations for the Sales App Flutter project. Use when the user asks about ESC/POS printer setup, PDF generation, Excel export, push notifications, background services, timezone handling, network scanning, file picking, Android intents, or connectivity checks.
---

# Integration Agent — Laminates Wholesaler Management App

## When to use this skill
- User asks about printer setup for Sales Challans
- User wants to implement or fix Thermal/Wi-Fi printing logic
- User wants to export Excel/PDF reports with specific filters
- User asks about connectivity handling for multi-shop data reloading

## Project Context
- **Printing (PRD §11):** Support for Thermal and Wi-Fi printers. **Print Preview** is mandatory before printing.
- **Exporting (PRD §7.6):** Support for Excel and PDF. Filters: Date Range, Module Type (Sales, Purchase, Stock).
- **Communication:** ESC/POS for thermal printing.

## Workflow

- [ ] Identify which third-party package is required (e.g., `pdf`, `excel`, `flutter_esc_pos_network`)
- [ ] Implement the Print Preview screen using the `printing` package
- [ ] Ensure the export logic respects the `shop_id` filter
- [ ] Add error handling for printer connection timeouts or invalid IPs
- [ ] Verify that exports are saved correctly to the device storage

## Instructions

### Thermal/Wi-Fi Printing Flow
1. Fetch Saved Printer IP from `SharedPreferences`.
2. Generate ESC/POS bytes for the Challan (Shop Details, Party, Items, Total).
3. Connect to printer via TCP (Port 9100 default).
4. Send bytes and disconnect.

### Challan Format Requirements
- Shop Details (Name, Contact)
- Party Details
- Item Table (Design No, Qty, Rate, Amount)
- Total Quantity and Total Amount

### Excel Export with Filters
```dart
Future<void> exportToExcel(DateTime start, DateTime end, String type) async {
  // 1. Fetch data from Supabase filtered by date, type, and shop_id
  // 2. Create Excel object and append rows
  // 3. Save to storage using path_provider
}
```

### PDF Layout Preview
```dart
import 'package:printing/printing.dart';

// In View
PdfPreview(
  build: (format) => controller.generatePdf(format),
)
```

## Resources
- Printer Utility: `lib/app/core/utils/printersetup.dart`
- Export Logic: `lib/ui/export/`
- Models: `lib/models/sales.dart`
