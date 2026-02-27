---
name: testing-and-qa
description: Designs and implements tests, QA checklists, and validation strategies for the Sales App Flutter project. Use when the user asks about writing unit tests, widget tests, integration tests, testing a controller, testing a repository, validating business logic, or performing QA on any module including Sales Entry, Stock View, Purchase, or Notifications.
---

# Testing & QA Agent — Laminates Wholesaler Management App

## When to use this skill
- User wants to write unit tests for shop-wise data logic
- User wants to validate business rules like stock deduction on sale
- User needs a QA checklist for the Sales, Stock, or Print modules

## Project Context
- **Primary Logic to Test:**
  - **Shop Isolation:** Ensure queries only return data for the `active_shop_id`.
  - **Stock Management:** Assert stock decreases on Sales Save and increases on Purchase.
  - **Validation:** Test that sales cannot exceed available stock.
  - **Auto-Generation:** Verify Invoice Numbers are unique per shop.

## Workflow

- [ ] Create tests in the `test/` directory
- [ ] Mock the Supabase client to simulate multi-shop data
- [ ] Write integration tests for the Shop Switching flow
- [ ] Use the PRD-based checklists below for manual or automated verification

## Instructions

### QA Checklist — Multi-Shop & Security (PRD §8, §14)
- [ ] User is forced to login before any operation.
- [ ] Shop selection is required/presented post-login.
- [ ] Switching shops updates all UI metrics (Today's Sales, etc.) immediately.
- [ ] Data from Shop A is never visible when Shop B is active.

### QA Checklist — Sales Module (PRD §7.2)
- [ ] Invoice numbers are unique within a shop.
- [ ] Multiple designs can be added to a single invoice.
- [ ] Saving a sale reduces stock in the correct location.
- [ ] "Recent Sales" list updates after saving.
- [ ] Printing triggers a preview before the actual print command.

### QA Checklist — Stock View (PRD §7.1)
- [ ] Design numbers, locations, and quantities match Supabase records.
- [ ] **Stock Transfer:** Deduction from source and addition to destination happens atomically.
- [ ] **Low Stock:** Designs with < 10 qty are flagged/listed.

### QA Checklist — Admin Module (PRD §5)
- [ ] Only Admin users can Add/Edit Shops.
- [ ] Marking a shop as Inactive hides it from the switcher.
- [ ] Folders and Product Heads can be managed successfully.

## Resources
- PRD reference: Section 10 (Business Logic) and Section 14 (Security).
- Shop Service: `lib/services/shop_providers.dart`
- Sales Logic: `lib/services/sales_providers.dart`
