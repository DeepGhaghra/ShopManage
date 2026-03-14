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

Every inner screen AppBar must follow this exact pattern for perfect uniformity:

```dart
AppBar(
  leadingWidth: 96,
  leading: Row(
    children: [
      const BackButton(color: AppColors.textPrimary),
      IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    ],
  ),
  centerTitle: true,
  surfaceTintColor: Colors.transparent,
  title: CustomAppBarTitle(
    title: 'Your Screen Title',
    subtitle: ref.watch(activeShopProvider)?.shopName,
  ),
  actions: const [
    AppBarActions(),
  ],
)
```

---

## 3. Scaffold & Background
... (rest of the file remains similar) ...

---

## 10. Full Screen Skeleton — COPY THIS

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/core_providers.dart';
import '../../theme/app_theme.dart';
import '../common/app_drawer.dart';
import '../common/app_bar_actions.dart';
import '../common/app_bar_title.dart';

class MyNewScreen extends ConsumerWidget {
  const MyNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leadingWidth: 96,
        leading: Builder(builder: (context) {
          return Row(
            children: [
              const BackButton(color: AppColors.textPrimary),
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ],
          );
        }),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: CustomAppBarTitle(
          title: 'My Screen',
          subtitle: ref.watch(activeShopProvider)?.shopName,
        ),
        actions: const [
          AppBarActions(),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/my-route'),
      body: const Center(child: Text('Content goes here')),
    );
  }
}
```
