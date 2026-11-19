# Bit Tool Standalone Module (`bit_tool_module`)

A complete, self-contained, and production-ready Flutter package providing the **Bit Tool Right Utility Rail**, full slide-out panels, and all 8 backend API modules.

This folder can be transferred, copied, or imported into **any Flutter desktop or web project** and will work end-to-end with zero missing dependencies, leaving host applications completely unaffected.

---

## 🌟 What is Included in this Module

### 1. The Right Side Utility Rail & All Slide-out Panels
The module contains the complete UI suite for all Bit Tool applications:
* **Beta Apps Directory**:
  * Dual tab navigation: **Favorites** & **Recent**.
  * Dynamic app directory (17+ integrated tools including Calculator, Calendar, Contacts, Notes, Mail, Meet, Passkey, Scanner, Tasks, Vault, VPN, YouPI, Weather, etc.).
  * Public vs. Business workspace filtering.
* **Calculator (`# BETA CALC`)**:
  * Real-time calculation tape with auto-scrolling log.
  * Instant tax & discount presets: **% GST (+5%, +12%, +18%, +28%)**, **Discount**, **INR Currency Format**, and **Compare Mode**.
  * Scientific operator keypad.
  * Tape Archives history drawer with **Clear All**, **Restore Session**, and live backend API persistence.
* **Calendar (`CALENDAR`)**:
  * Interactive monthly calendar grid with month navigation and active day highlight.
  * **Add New** modal with multi-tab support: **Event**, **Note**, and **Reminder** with title, description, and time pickers.
  * Today's agenda list and pending reminders with interactive completion checkboxes (`LucideIcons.circleCheck`).
* **Notes (`NOTES`)**:
  * Clean **My Notes** subheader with a blue **+ New Note** pill button.
  * Pinned notes section and color-coded sticky note cards.
  * Modal note creation and editing dialog with 8 curated color swatches and pin toggle.
* **Contacts & CRM (`GLOBAL CONTACTS`)**:
  * Real-time contact search bar (filters by name, role, email, or company).
  * Blue **+ Add Contact** pill button.
  * Clean **Create New Contact** modal dialog with First Name, Last Name, Email, Phone, Company, and Role.
* **Weather (`WEATHER`)**:
  * Dynamic hero gradient card with live temperature, weather condition text, humidity, and wind speed.
  * Multi-city quick switch pills: **Tiruvallur**, **Chennai**, **Bengaluru**, **Mumbai**, **Delhi**, **London**, **New York**.
  * 24-Hour forecast horizontal strip.
  * 7-Day extended forecast with visual temperature range progress bars.
* **Virtual Keyboard (`KEYBOARD`)**:
  * Interactive on-screen keyboard with **ABC**, **123 & Symbols**, and **Emojis** layouts.
  * Live typed text preview with copy-to-clipboard and clear actions.
* **Drawer Toggle & Quick Note**:
  * Bottom quick actions for instant note drafting and drawer open/close.

---

## 🎨 Recent UI Refinements Included
* **No Mini Tabs / No Popup Menus**: The cramped in-drawer overlay tabs and popup menu from the rail have been removed. Every action now opens a clean, properly centered modal dialog (`showDialog`).
* **Self-Contained Bundled Assets**: All images (`beta_logo.png`, `cliks_business_img.png`, `bnx_mail_logo.png`, `cliks_logo.png`, `bit_tool_logo.png`, `icon.png`, `icon2_image.png`) are bundled inside `bit_tool_module/assets/images/`. No machine-specific or absolute file paths are required.
* **Dynamic Multi-Account Syncing**: Switching accounts in the host application automatically triggers a refresh across all Bit Tool panels.

---

## 📁 Directory Structure

```
bit_tool_module/
├── lib/
│   ├── bit_tool_module.dart              # Main library export barrel
│   └── src/
│       ├── api/                          # Standalone API Client & 8 Modules
│       │   ├── client/                   # Authenticated HTTP client with Bearer auth
│       │   ├── config/                   # Base URLs & endpoint descriptors
│       │   ├── facade/                   # BitToolApiModule facade
│       │   └── modules/                  # 8 modular service implementations:
│       │       ├── calculator/           # Calculator API service & models
│       │       ├── calendar/             # Calendar & Reminders API
│       │       ├── contacts/             # Contacts CRUD & pagination API
│       │       ├── currency/             # Currency exchange API
│       │       ├── notes/                # Notes CRUD & pin API
│       │       ├── notifications/        # Notifications polling & badge API
│       │       ├── user_profile/         # User profile metadata API
│       │       └── weather/              # Open-Meteo weather API
│       ├── providers/                    # Riverpod state notifiers & providers
│       │   └── bit_tool_providers.dart   # Central reactive state management
│       └── ui/                           # UI Components
│           ├── bit_tool_right_utility_rail.dart # Right rail & slide-out panels
│           └── calculator/
│               └── bit_tool_calculator.dart     # Beta Calculator
├── assets/
│   └── images/                           # Bundled logos & brand assets
├── example/                              # Runnable end-to-end demo app
│   └── lib/
│       └── main.dart                     # Standalone host integration example
├── test/
│   └── bit_tool_module_test.dart         # Unit & widget integration test suite
├── pubspec.yaml
└── README.md
```

---

## 🚀 How to Transfer & Implement in Any Project

### Step 1: Copy or Transfer the Folder
Copy the entire `bit_tool_module` folder into your new workspace or repository (e.g., at the root or under `packages/bit_tool_module`).

### Step 2: Add Dependency in Host `pubspec.yaml`
In your host application's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  lucide_icons_flutter: ^3.1.14+2
  bit_tool_module:
    path: ./bit_tool_module   # or relative path where you placed the folder
```

Run:
```bash
flutter pub get
```

### Step 3: Provide Host Session Token & Active Account
The module is decoupled from any single authentication backend. In your host application setup or root widget, supply the token callback and active account:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bit_tool_module/bit_tool_module.dart';

void configureBitTool(WidgetRef ref) {
  // 1. Supply token retrieval callback
  ref.read(bitToolTokenProvider.notifier).state = () async {
    return await myAuthService.getAccessToken(); // returns Bearer JWT
  };

  // 2. Keep the active account in sync
  ref.read(bitToolActiveAccountProvider.notifier).state = BitToolHostAccount(
    id: currentUser.id,
    email: currentUser.email,
    name: currentUser.displayName,
  );
}
```

### Step 4: Mount the Rail in your App's Layout
Wrap your app in `ProviderScope` (standard for Riverpod) and position `BitToolRightUtilityRail` inside a `Stack` at the top right of your layout:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bit_tool_module/bit_tool_module.dart';

class MyWorkspaceScreen extends StatelessWidget {
  const MyWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Host Application Main View / Dashboard
          const MyMainDashboardView(),

          // 2. Bit Tool Right Utility Rail
          const Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: BitToolRightUtilityRail(),
          ),
        ],
      ),
    );
  }
}
```

---

## 🧪 Try the Included Example App

A complete runnable application is included in `example/lib/main.dart`. You can run it directly:

```bash
cd bit_tool_module
flutter run -t example/lib/main.dart
```

This launches a clean workspace with the Bit Tool right utility rail fully functional out-of-the-box.
