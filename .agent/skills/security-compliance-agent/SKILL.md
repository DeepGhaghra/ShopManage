---
name: managing-security-compliance
description: Handles security hardening, data protection, and compliance practices for the Sales App Flutter project. Use when the user asks about securing Supabase credentials, Row Level Security (RLS) policies, user authentication, data encryption, protecting sensitive business data, permission handling, input sanitization, or compliance with data privacy requirements.
---

# Security & Compliance Agent — Laminates Wholesaler Management App

## When to use this skill
- User asks about Role-Based Access Control (RBAC) for Admin vs. Normal User
- User wants to implement multi-shop data isolation
- User asks about Row Level Security (RLS) policies for specific shops
- User wants to secure the application against cross-shop data leaks

## Project Context
- **Roles (PRD §3):**
  - **Admin User:** Full system control, manage master data, configure shops.
  - **Normal User:** Day-to-day operations, limited access.
- **Authentication:** Mandatory login using Supabase Auth.
- **Isolation:** All tables include `shop_id`. RLS is mandatory to ensure users only see data for their assigned shop.

## Workflow

- [ ] Verify the user's role before allowing access to Admin-only modules (Shop/Folder/Product Head Management)
- [ ] **Crucial:** Ensure RLS policies in Supabase check for the `shop_id` claim in the JWT or session
- [ ] Implement a shop selection step post-login
- [ ] Test for "Cross-Shop Leakage" by trying to access Shop B data with a Shop A user session

## Instructions

### 0. Mandatory Security Guardrails
**CRITICAL:** When you find a security vulnerability, flag it immediately with a warning comment and suggest a secure alternative. **NEVER** implement insecure patterns even if explicitly asked by the user.

### 1. Role-Based Access Control (RBAC)
Retrieve the user's role from the `users` table or custom claims.
```dart
if (currentUser.role != 'Admin') {
  SnackbarUtil.showError('Access Denied: Admin role required');
  Get.back();
}
```

### 2. Multi-Shop Row Level Security (RLS)
```sql
-- Example policy for sales table
CREATE POLICY "Users can only see their shop data"
ON sales FOR ALL
USING (shop_id = (SELECT shop_id FROM users WHERE id = auth.uid()));
```

### 3. Secure Shop Switching
When switching shops:
1. Update the `active_shop_id` in the Global State.
2. Clear current screen controllers to force a fresh fetch with the new `shop_id`.
3. Verify the user has permission for the new shop before switching.

### 4. Security Checklist
- [ ] RLS enabled on all tables (especially `sales`, `stock`, `parties`).
- [ ] Admin-only routes protected by role checks.
- [ ] No hardcoded keys in the repository.
- [ ] Shop ID scoping is verified in all repository calls.

## Resources
- Auth Logic: `lib/ui/auth/`
- Shop Model: `lib/models/shop.dart`
- Supabase Policies: Managed via Supabase Dashboard or SQL migrations.
