# macOS Standalone Storage Management Suite

A self-contained, enterprise-grade macOS desktop storage management interface built for Flutter. This module contains everything related to the macOS Storage experience: all views, dialogs, charts, widgets, models, and assets.

---

## 📁 Directory Structure

```
standalone_macos_storage/
├── standalone_macos_storage.dart      # Primary barrel export file
├── pages/
│   └── macos_storage_page.dart        # Complete macOS Storage Page (6,300+ lines of high-fidelity UI)
├── widgets/
│   ├── storage_breakdown_dialog.dart  # Modal dialog launcher
│   └── sidebar_storage_card.dart      # Compact storage card for sidebars & nav rails
├── models/
│   └── storage_models.dart            # Data structures for apps, files, quotas & recycle bin
├── assets/                            # Bundled logo assets & branding
│   ├── beta_logo_hd.png               # High-definition blue Beta logo
│   ├── beta_logo .jpg                 # Fallback beta logo
│   ├── bnx_mail_logo.png              # BNX Mail branding logo
│   ├── cliks_logo.png                 # Cliks core branding logo
│   └── cliks_business_img.png         # Cliks Business branding logo
├── README.md                          # Integration & usage guide (this file)
└── DESIGN_DOCUMENT.md                 # Full UI/UX design specifications & tokens
```

---

## 🎨 Design Overview & UI Architecture

The interface follows the Apple macOS Human Interface Guidelines (HIG) with modern desktop design aesthetics:

### 1. Top Header Bar
- **Back Navigation**: Fluid back button with tooltip and automatic `Navigator.pop()` or custom `onBack` handler.
- **Beta Brand Identity**: High-DPI Beta badge with rounded glass border, hover cursor, and click handler.
- **Account Dropdown**: Pill-shaped action button opening a profile card with user avatar, email (`ravinew2004@bnxmail.com`), account management options, and sign-out actions.

### 2. Desktop Two-Pane Layout
- **Left Navigation Rail (220px)**:
  - **Home**: Overview of total storage and ecosystem health.
  - **Application Storage**: Dedicated views for BNX Mail, Cliks, and Cliks Business.
  - **Storage Management**: Deep-dive Storage Usage analytics, Recycle Bin with pagination, and Manage Apps.
  - **System**: Granular storage settings.
- **Main Canvas**:
  - Dynamically switches views with smooth transitions and bouncing desktop scroll physics.

### 3. Dedicated Views
1. **Home / Overview**:
   - Top banner with total capacity (e.g. 1.00 GB), percentage bar, high-usage alert badge.
   - Breakdown cards for each ecosystem app with live progress bars and item counts.
   - Recent storage activity audit log.
   - Quick clean recommendations.
2. **Cliks Business Storage**:
   - Custom-painted single donut ring gauge displaying quota utilization.
   - Storage breakdown by business category (Invoices, Inventory, Customer records, Audit docs).
   - Storage limit settings and quota modification tools.
3. **Storage Usage (Analytics)**:
   - Interactive multi-segment storage distribution bar.
   - Categorical breakdown (Documents, Media, Archives, System).
   - Largest Files Table with filename, original directory path, file size, last modified date, and individual action buttons (Preview, Download, Delete).
4. **Recycle Bin**:
   - App-level filter chips (ALL, BNX Mail, Cliks, Cliks Business).
   - Real-time search filter for deleted files.
   - "Empty Recycle Bin" button with confirmation modal.
   - Paginated file cards with "Restore" and "Delete Permanently" actions.
5. **BNX Mail Storage**:
   - Mailbox breakdown (Inbox, Sent, Archive, Trash).
   - Large attachment management and one-click cleanup suggestions.
6. **Cliks App Storage**:
   - Cloud drive files, chat attachments, channel media consumption.
7. **Manage Apps**:
   - Connection pool size controller (`TextEditingController`).
   - App sync toggles and storage allocation sliders.
8. **Settings**:
   - Three tabbed sub-sections: General, Privacy, and Connected Apps.
   - Storage unit selector (`GB` vs `TB`).
   - Decimal precision selector (`2 digits`, etc.).
   - Theme mode (`Light`, `System`, `Dark`).
   - Storage access permissions (`only_me`, `connected`, `shared`).

### 4. Custom Painters
- `_DonutRingPainter`: High-performance custom canvas painter for circular storage gauges.
- `_EcosystemDonutChartPainter`: Multi-color ecosystem storage breakdown donut.
- `_BnxMailIconPainter`: Vector path painter for BNX Mail envelope & wing logo.
- `_DottedLinePainter`: Vector dotted separator for receipt/invoice alignment.

---

## 🚀 How to Add to a New Project

### Step 1: Copy the Folder
Copy the entire `standalone_macos_storage/` folder into your new project's `lib/` directory:
```
my_new_project/
  └── lib/
      └── standalone_macos_storage/
```

### Step 2: Add Dependencies to `pubspec.yaml`
Ensure your new project has the following packages in `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1      # State management
  google_fonts: ^6.2.1          # Typography (Inter font)
  lucide_icons_flutter: ^1.1.0  # Crisp macOS icons
```

### Step 3: Register Assets (Optional but Recommended)
In your `pubspec.yaml`, register the bundled assets if you want local image resolution:
```yaml
flutter:
  assets:
    - lib/standalone_macos_storage/assets/
```
*(Note: If assets are not declared in `pubspec.yaml`, the UI will automatically fall back to built-in vector CustomPainters without throwing any runtime errors).*

### Step 4: Import and Use

#### A. Open as a Full-Screen Page:
```dart
import 'package:flutter/material.dart';
import 'standalone_macos_storage/standalone_macos_storage.dart';

void openStoragePage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => MacOsStoragePage(
        onBack: () => Navigator.of(context).pop(),
        backButtonTooltip: 'Back to Dashboard',
      ),
    ),
  );
}
```

#### B. Open as a Modal / Dialog:
```dart
import 'standalone_macos_storage/standalone_macos_storage.dart';

// Using the built-in dialog launcher:
MacOsStorageBreakdownDialog.show(context);
```

#### C. Embed in your App's Sidebar:
```dart
import 'standalone_macos_storage/standalone_macos_storage.dart';

// In your sidebar or navigation rail widget list:
SidebarStorageCard(
  title: 'Storage',
  usageText: '0 KB of 1.00 GB used',
  progress: 0.05,
)
```

#### D. If Your New Project Doesn't Use Riverpod Globally:
Simply wrap `MacOsStoragePage` in a `ProviderScope`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'standalone_macos_storage/standalone_macos_storage.dart';

ProviderScope(
  child: MacOsStoragePage(),
)
```

---

## ⚙️ Customization Parameters

`MacOsStoragePage` accepts optional callbacks:
- `onBack`: Custom action when the top-left return arrow is tapped. If omitted, it automatically calls `Navigator.of(context).pop()`.
- `onBetaLogoTap`: Custom action when the top Beta logo is clicked.
- `backButtonTooltip`: Custom tooltip for the back button (defaults to `'Back to App'`).
