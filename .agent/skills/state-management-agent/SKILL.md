---
name: managing-state-getx
description: Implements and manages reactive state using GetX for the Sales App Flutter project. Use when the user asks about controllers, observables, bindings, reactive variables, GetX dependency injection, controller lifecycle, or state not updating correctly in any module.
---

# State Management Agent — Laminates Wholesaler Management App

## When to use this skill
- User asks how to add reactive state to a screen
- User wants to implement Shop Switching logic
- User reports data not reloading after switching shops
- User needs to manage global state (User role, active shop) using GetX

## Project Context
- **Framework:** GetX
- **Key Reactive Fields:** 
  - `activeShopId.obs`
  - `currentUserRole.obs`
  - `isLoading.obs`
- **Dynamic Reloading:** All functional modules (Stock, Sales, Purchase) must listen to `activeShopId` changes or be re-initialized on switch.

## Workflow

- [ ] Define global observables in a `GlobalController`
- [ ] Implement a `refreshData()` method in each functional controller
- [ ] **Shop Switch Flow:**
  1. User selects a new shop in the Sidebar/Drawer.
  2. Update `activeShopId.value`.
  3. Trigger `refreshData()` on the current screen's controller.
- [ ] Use `ever(activeShopId, (_) => handleShopChange())` for reactive listeners.

## Instructions

### Global Controller Template
```dart
class GlobalController extends GetxController {
  final activeShopId = ''.obs;
  final role = 'Normal User'.obs;

  void switchShop(String newShopId) {
    activeShopId.value = newShopId;
    // Notify other controllers or trigger global reloads
  }
}
```

### Reactive Listening in Module Controller
```dart
class StockController extends GetxController {
  final global = Get.find<GlobalController>();

  @override
  void onInit() {
    super.onInit();
    // Listen for shop changes and reload data automatically
    ever(global.activeShopId, (_) => fetchData());
    fetchData();
  }
  
  // ...
}
```

### Navigation & State
- Post-login: Fetch user's assigned shops and set the default `activeShopId`.
- Ensure all repository calls use `Get.find<GlobalController>().activeShopId.value`.

## Resources
- Global State: `lib/services/shop_providers.dart` (or global controller)
- Routes: `lib/routing/router.dart`
- Module Controllers: `lib/services/`
