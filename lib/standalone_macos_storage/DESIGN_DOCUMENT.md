# macOS Storage Page — Design System & UI Specifications

This document details the visual design, token systems, UI architecture, layout specifications, and component behaviors of the macOS Storage page.

---

## 1. Visual Hierarchy & Philosophy

The storage page adheres to modern desktop design principles:
- **Clean Whitespace & Separation**: Distinct borders with hairline thickness (`1.0px`), subtle shadow elevations, and crisp contrast.
- **Mac Native Aesthetics**: Crisp Lucide vector iconography, SF-style typography rendering via Google Fonts `Inter`, and platform-tailored cursor interactions (`SystemMouseCursors.click`).
- **Data Scannability**: Visual gauges, colored status capsules, and tabular breakdown layouts for quick information digestion.

---

## 2. Color Palette & Design Tokens

### Backgrounds & Surfaces
| Token Name | Hex Code | Purpose |
| :--- | :--- | :--- |
| `surfacePrimary` | `#FFFFFF` | Main canvas, cards, and sidebar background |
| `surfaceSecondary` | `#F8FAFC` | Table headers, secondary containers, and badges |
| `surfaceAccent` | `#F1F5F9` | Icon buttons, back button container |
| `surfaceHighlight` | `#EFF6FF` | Sidebar storage card background |

### Borders & Dividers
| Token Name | Hex Code | Purpose |
| :--- | :--- | :--- |
| `borderLight` | `#E2E8F0` | Structural dividers, sidebar borders, header bottom line |
| `borderMedium` | `#CBD5E1` | Input fields, card outlines, subtle dividers |
| `borderAccent` | `#DBEAFE` | Storage indicator and highlighted card outlines |

### Text & Content
| Token Name | Hex Code | Purpose |
| :--- | :--- | :--- |
| `textPrimary` | `#0F172A` | Major titles, section headings, bold metrics |
| `textSecondary` | `#334155` | Body text, table rows, button labels |
| `textMuted` | `#64748B` | Subtitles, timestamps, table column headers |
| `textHint` | `#94A3B8` | Sidebar group headers, empty state text |

### Brand & Functional Colors
| Token Name | Hex Code | Purpose |
| :--- | :--- | :--- |
| `brandPrimary` | `#2563EB` | Active nav items, primary buttons, links, progress bars |
| `brandPrimaryDark`| `#1D4ED8` | Button hover and pressed states |
| `brandSuccess` | `#16A34A` | Healthy storage status, Cliks Business accent |
| `brandWarning` | `#F59E0B` | Warning threshold, moderate quota consumption |
| `brandDanger` | `#EF4444` | High-usage alert badge, permanent deletion, empty bin |
| `brandPurple` | `#6366F1` | Account avatar gradient, analytics category |

---

## 3. Typography Hierarchy (Google Fonts `Inter`)

| Element | Font Size | Weight | Line Height / Letter Spacing | Color |
| :--- | :--- | :--- | :--- | :--- |
| **Page Title** | `24px` | `w800` (Extra Bold) | `-0.5px` letter spacing | `#0F172A` |
| **Section Header** | `18px` | `w700` (Bold) | `-0.3px` letter spacing | `#0F172A` |
| **Card Header** | `15px` | `w600` (Semi Bold) | Normal | `#1E293B` |
| **Body Bold** | `13px` | `w600` (Semi Bold) | Normal | `#0F172A` |
| **Body Regular** | `13px` | `w400` / `w500` | `1.4` line height | `#334155` |
| **Sidebar Group Label** | `9.5px` | `w700` (Bold) | `+0.6px` letter spacing (Caps) | `#94A3B8` |
| **Table Header** | `11.5px` | `w600` (Semi Bold) | `+0.4px` letter spacing (Caps) | `#64748B` |
| **Micro Caption** | `9.5px` | `w500` (Medium) | Normal | `#64748B` |

---

## 4. Layout & Dimensions

- **Total Layout**: Responsive `Row` under a persistent `60px` top header bar.
- **Top Bar**:
  - Height: `60px`
  - Horizontal Padding: `24px`
  - Left: Back button (`30px x 30px` rounded container) + Beta logo badge (`26px x 26px`) + `Beta` label
  - Right: Account pill button (`16px x 8px` padding, `#2563EB`)
- **Left Navigation Sidebar**:
  - Fixed Width: `220px`
  - Border: Right border `1px solid #E2E8F0`
  - Content: Vertical `ListView` with section dividers and group headers
  - Selection Highlight: Solid `#2563EB` fill with white text and `6px` shadow blur
- **Main View Area**:
  - Fill remaining horizontal space (`Expanded`)
  - Padding: Horizontal `36px`, Vertical `28px`
  - Scroll Physics: `BouncingScrollPhysics`

---

## 5. UI Components Breakdown

### 1. Storage Overview Metric Card
- Shows used quota vs. maximum quota (e.g. `0 KB / 1.00 GB`).
- Contains a customized `LinearProgressIndicator` with rounded ends.
- Includes quick-action buttons: "Free Up Space" and "Upgrade Storage".
- Status indicator pill: "Optimal" (Green) or "Critical" (Red).

### 2. Application Breakdown Cards (Grid/List)
- Each card represents an app in the ecosystem:
  - **BNX Mail**: Email & attachments usage
  - **Cliks**: Workspaces, chat history, channel media
  - **Cliks Business**: Invoices, inventory logs, accounting documents
- Shows individual progress bars, percentage of total pool, and file count.

### 3. Analytics & Largest Files Table
- Column headers:
  - File Name (with file-type icon: PDF, Image, Spreadsheet, Archive)
  - Location / Path
  - File Size
  - Last Modified Date
  - Actions (Preview icon, Download icon, Delete icon)
- Hover effect on rows with soft `#F8FAFC` background.

### 4. Recycle Bin
- Header with item count and total reclaimable space.
- Search input with clear button.
- Filter buttons: `ALL`, `BNX Mail`, `Cliks`, `Cliks Business`.
- Item card with:
  - File type icon
  - Deletion timestamp
  - Days remaining before auto-deletion (e.g., 30 days retention policy)
  - Action buttons: "Restore" (Blue) and "Delete" (Red outline).

### 5. Settings Sub-Panel
- Tab navigation: `General` | `Privacy` | `Connected Apps`.
- Form controls:
  - Custom dropdowns for unit preference (`GB` / `TB`) and decimal precision.
  - Radio cards for storage access permission (`Only Me`, `Connected Accounts`, `Public Organization`).
  - Toggle switches for usage percentage display, alert notifications, and dark mode.

---

## 6. Custom Canvas Painters

1. **`_DonutRingPainter`**:
   - Computes angular arcs with gap spacing between segments.
   - Smooth stroke endings with `StrokeCap.round`.
   - Used for single app storage percentage.

2. **`_EcosystemDonutChartPainter`**:
   - Multi-segment radial gauge dividing storage across BNX Mail, Cliks, Cliks Business, and free space.
   - Center text displaying percentage or used capacity.

3. **`_BnxMailIconPainter`**:
   - Vector canvas path drawing an envelope with an aerodynamic wing/airplane motif.
   - Eliminates raster pixelation at any resolution.
