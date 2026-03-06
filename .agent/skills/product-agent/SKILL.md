---
name: managing-product-features
description: Manages product feature planning, backlog grooming, and requirements for the Sales App Flutter project. Use when the user asks about adding new features, changing module behavior, defining acceptance criteria, prioritizing backlog items, or planning new screens across modules like Stock View, Sales Entry, Purchase, Party management, Price List, or Party Sales Target.
---

# Product Agent — Laminates Wholesaler Management App

## When to use this skill
- User asks to add, modify, or remove a feature in any module
- User wants to define acceptance criteria or business rules (e.g., stock deduction on save)
- User asks to plan a new module or extend an existing one (e.g., Sales, Purchase, Stock View)
- User mentions shop-wise data isolation or multi-shop management
- User asks about Admin vs. Normal User role permissions

## Project Context
- **App:** Laminates Wholesaler Management App (Flutter + GetX + Repository)
- **Backend:** Supabase (PostgreSQL + RLS)
- **Architecture:** Multi-shop with dynamic switching (all data is `shop_id` scoped)
- **Roles:** Admin User (Full control), Normal User (Day-to-day operations)

## Modules & Features (PRD §5-§7)

### Admin Module
- **Shop Management:** Add/Edit/Inactive Shops. 
- **Shop Onboarding (Future):** Whenever a new shop is entered, automatically pre-populate it with default **locations** and **product designs** to ensure it's ready for immediate use.
- **Folder Management:** Category layer for organizing product heads.
- **Product Head Management:** Manage types like Sunmica, Texture, Acrylic.

### Operational Modules
- **Dashboard:** Today’s Sales Count, Top Trending Design, Low Stock List.
- **Stock View:** Table view of Design Number/Location/Qty. **Transfer Stock** log.
- **Sales Module:** Auto-generated unique invoice per shop. Multi-item entries. **Stock deduction on save**.
- **Purchase Module:** Add stock via purchase, auto update inventory.
- **Parties Module:** Manage buyers/suppliers. Searchable dropdowns.
- **Price List:** Mapping between Product Head and Rate for auto-filling.
- **Export Data:** Excel/PDF export with filters (Date Range, Module Type).

## Workflow

- [ ] Identify which module the feature belongs to
- [ ] Note if the change requires an Admin-only permission
- [ ] Define the user story: *As a [Admin/User], I want [action] so that [benefit]*
- [ ] Identify data fields: Must include `shop_id` column for new tables
- [ ] Note cross-module impact (e.g., Sales Entry deductions affect Stock View)
- [ ] Ensure unique constraints align with PRD (e.g., Invoice No unique per shop)

## Instructions

### Key Business Logic (PRD §10)
- **Sales:** Always deduct stock from the specific location selected.
- **Purchase:** Always increase stock.
- **Stock Transfer:** Deduct from source and add to destination in a single transaction; maintain a log.
- **Low Stock:** Flag items where quantity < 10 (default threshold).
- **Trending:** Based on daily sales frequency.

### Module Ownership Map
| Module | Primary Data Source | Key Entities |
|---|---|---|
| Admin | `shops`, `folders`, `product_heads` | Shop, Folder, Product Head |
| Stock | `stock`, `stock_transactions` | Design Number, Location, Qty |
| Sales | `sales`, `sales_items` | Invoice, Party, Design, Rate, Qty |
| Purchase| `purchases` | Party, Design, Qty |
| Parties | `parties` | Name, Mobile, City |
| Pricing | `price_list` | Product Head, Price |

### Rules
- **Multi-Shop:** All data queries must filter by `active_shop_id`.
- **Validation:** Never allow selling stock that exceeds available quantity at a location.
- **Soft Delete:** Use `is_active` or `status` flags instead of hard deletes where possible.

## Resources
- PRD reference: See the project documentation provided in conversation.
- Routes: `lib/routing/router.dart`
- Models: `lib/models/`
