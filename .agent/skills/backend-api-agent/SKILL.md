---
name: managing-backend-api
description: Handles Supabase backend operations, database queries, and API layer for the Sales App Flutter project. Use when the user asks about Supabase table queries, RLS policies, CRUD operations, repository files, data models, Supabase functions, or SQLite schema changes for any module.
---

# Backend/API Agent — Laminates Wholesaler Management App

## When to use this skill
- User asks to add/modify a Supabase query (select, insert, update, delete)
- User needs to update the database schema (e.g., adding `shop_id` to a table)
- User asks about Row Level Security (RLS) or multi-shop data isolation
- User wants to implement specific logic for Sales (stock deduction) or Purchase (stock increase)

## Project Context
- **Backend:** Supabase (`supabase_flutter`)
- **Isolation:** **Multi-shop data isolation** is critical. Every table must have a `shop_id`.
- **Database Tables (PRD §9):**
  - `shops`, `folders`, `product_heads`, `parties`, `stock`, `stock_transactions`, `sales`, `sales_items`, `purchases`, `price_list`.
- **Repository Pattern:** Logic for each module is located in `lib/services/` or `lib/app/modules/*/repository/`.

## Workflow

- [ ] Identify which Supabase tables are affected by the request
- [ ] **Crucial:** Ensure all queries include a filter for `shop_id` (e.g., `.eq('shop_id', activeShopId)`)
- [ ] Verify RLS policies are in place to prevent cross-shop data leakage
- [ ] Implement database transactions for complex operations (like Stock Transfer)
- [ ] Document any new columns or table relationships

## Instructions

### Multi-Shop Query Pattern
Always filter by the current shop ID retrieved from the global state or session.
```dart
Future<List<Map<String, dynamic>>> fetchStock(String shopId) async {
  return await _client
      .from('stock')
      .select('*, designs(*)')
      .eq('shop_id', shopId) // MUST include shop_id filter
      .order('created_at', ascending: false);
}
```

### Stock Deduction Logic (Sales)
When a sale is saved, deduct quantity from the `stock` table for the specific shop and location.
```sql
-- Conceptual logic for a stock update function
CREATE OR REPLACE FUNCTION deduct_stock(p_shop_id UUID, p_design_id UUID, p_location_id UUID, p_qty INT)
RETURNS void AS $$
BEGIN
  UPDATE stock 
  SET quantity = quantity - p_qty
  WHERE shop_id = p_shop_id 
    AND design_id = p_design_id 
    AND location_id = p_location_id;
END;
$$ LANGUAGE plpgsql;
```

### Required Columns for All Tables
- `id` (PK)
- `shop_id` (FK to shops table)
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

### Row Level Security (RLS) Rules
- Enable RLS on all tables.
- Create policies that restrict access based on `auth.uid()` and the user's assigned `shop_id`.

## Resources
- Database Schema: Reference `database_schema.sql` if it exists.
- Models: `lib/models/`
- Supabase Client: Initialized in `lib/main.dart`.
