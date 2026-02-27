---
description: Creating a new inner screen with the standard app theme
---

# New Inner Screen — UI Standards

// turbo-all

## Rules for ALL new inner screens in this app

Every new screen MUST follow the **Slate Charcoal** brand theme defined in `lib/theme/app_theme.dart`.

---

## 1. Always import AppColors

```dart
import '../../theme/app_theme.dart';
```

---

## 2. AppBar Template

Every inner screen AppBar must follow this exact pattern:

```dart
AppBar(
  // backgroundColor, elevation, surfaceTintColor all come from ThemeData — do NOT override
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Screen Title'), // bold, dark — inherited from appBarTheme
      if (activeShop != null)
        Row(
          children: [
            const Icon(Icons.storefront_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              activeShop.shopName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,   // ← ALWAYS AppColors.accent, never orange/blue
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
    ],
  ),
  iconTheme: const IconThemeData(color: AppColors.textPrimary),
)
```

---

## 3. Scaffold & Background

```dart
Scaffold(
  backgroundColor: AppColors.scaffoldBg, // or just leave it — inherited from ThemeData
  ...
)
```

---

## 4. Cards

```dart
Card(
  elevation: 0,
  color: AppColors.cardBg,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: AppColors.divider),
  ),
  ...
)
```

---

## 5. Primary Buttons

```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    // Other styles inherited from ThemeData
  ),
  ...
)
```

## 6. Secondary / Ghost Buttons

```dart
ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary.withAlpha(20),
  foregroundColor: AppColors.primary,
  elevation: 0,
)
```

---

## 7. Accent / Icon Colors

| Usage | Color |
|---|---|
| Primary icons, borders | `AppColors.primary` (#263238) |
| Shop subtitle in AppBar | `AppColors.accent` (#546E7A) |
| Secondary text | `AppColors.textSecondary` |
| Success message | `AppColors.success` |
| Error message | `AppColors.error` |

---

## 8. Snackbars

```dart
SnackBar(
  content: const Text('✅ Done!'),
  backgroundColor: AppColors.primary,   // success: AppColors.success | error: AppColors.error
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
)
```

---

## 9. Colors to NEVER use in inner screens

| ❌ Avoid | ✅ Use instead |
|---|---|
| `Colors.deepOrange` | `AppColors.primary` |
| `Colors.orangeAccent` | `AppColors.accent` |
| `Color(0xFF0F4C81)` (old blue) | `AppColors.primary` |
| `Colors.blue` | `AppColors.primary` |
| `Theme.of(context).primaryColor` | `AppColors.primary` |

> **Exception**: Dashboard Quick Operations cards keep their individual colors
> (`AppColors.cardStock`, `AppColors.cardSales`, etc.) — those are intentional module identifiers.

---

## 10. Full Screen Skeleton

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/core_providers.dart';
import '../../theme/app_theme.dart';

class MyNewScreen extends ConsumerWidget {
  const MyNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeShop = ref.watch(activeShopProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Screen'),
            if (activeShop != null)
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(activeShop.shopName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
                ],
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: const Center(child: Text('Content goes here')),
    );
  }
}
```
