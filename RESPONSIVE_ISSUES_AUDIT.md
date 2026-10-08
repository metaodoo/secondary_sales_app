# Responsive Layout Issues Audit & Remediation Guide

## 1. Executive Summary: Why Does It Look Fine on One Phone But Break on Another?

Flutter calculates layout constraints on each frame. On standard modern devices (e.g., Pixel 7/8, iPhone 13/14 Pro) with **390dp – 412dp screen width**, ample horizontal room prevents layout overflow errors. However, on other devices, layouts break into yellow-and-black striped **`RenderFlex overflowed`** errors or unreadable clipped content due to:

1. **Narrow Screen Widths (320dp – 360dp)**:
   - Popular entry-level/mid-range Android devices (e.g., Samsung Galaxy A03/A12, Xiaomi Redmi series, older devices) have 320dp to 360dp of logical width.
   - Fixed-size paddings, multi-button rows, and unconstrained text strings push beyond the screen width.
2. **System Font Scaling & Display Zoom (1.15× – 1.3×)**:
   - When users set their phone OS font size to "Large" or enable "Display Zoom", text strings require 15%–30% more width and height. Rigid heights, static `childAspectRatio`s in `GridView`, and fixed-width containers immediately break.
3. **Short Vertical Heights (< 640dp) & Virtual Keyboards**:
   - Small screens or open soft keyboards shrink available vertical space. Modal bottom sheets lacking `isScrollControlled: true` or `SingleChildScrollView` overflow vertically.

---

## 2. Catalog of Identified Responsive Issues & Resolution Status

### Category A: Crowded Multi-Button Action Rows (Severe Text Clipping & Squishing)

| # | Screen / Component | File & Lines | Status | Resolution Applied |
|---|-------------------|--------------|--------|--------------------|
| 1 | **Modern Trade Customer Action Sheet** | [`mt_customer_action_bottom_sheet.dart:845-850`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/modern_trade/screens/mt_customer_action_bottom_sheet.dart#L845-L850) | **FIXED** | Replaced rigid single `Row` of 6 buttons with responsive `LayoutBuilder` + `Wrap` (3 buttons per row on narrow/standard devices, ~98dp width each instead of ~45dp). Wrapped sheet in `SingleChildScrollView`. |
| 2 | **General Trade Customer Action Sheet** | [`customer_action_bottom_sheet.dart:531-614`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/routes/screens/customer_action_bottom_sheet.dart#L531-L614) | **FIXED** | Replaced rigid 5-button `Row` with responsive `LayoutBuilder` + `Wrap` (3 columns), doubling button width on narrow screens. Wrapped sheet in `SingleChildScrollView`. |

---

### Category B: Bare `Row`s with Variable Text & Badges (RenderFlex Overflow on Right)

| # | Screen / Component | File & Lines | Status | Resolution Applied |
|---|-------------------|--------------|--------|--------------------|
| 3 | **Leave Dashboard Approval Cards** | [`leave_dashboard_screen.dart:518-552`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/hr/screens/leave_dashboard_screen.dart#L518-L552) | **FIXED** | Placed `Applied: Date` on its own line and wrapped `Reject` / `Approve` buttons in a full-width `Row` with `Expanded`. |
| 4 | **Expense Dashboard Approval Cards** | [`expense_dashboard_screen.dart:562-585`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/hr/screens/expense_dashboard_screen.dart#L562-L585) | **FIXED** | Wrapped `Reject` and `Approve` buttons in `Expanded` across the card action row. |
| 5 | **Dashboard Sales Order Card** | [`dashboard_cards.dart:189-228`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/core/widgets/dashboard_cards.dart#L189-L228) | **FIXED** | Wrapped `order.name` in `Expanded` with `TextOverflow.ellipsis` and added 8dp spacing before amount & badge. |
| 6 | **Modern Trade Stock Audit List Cards** | [`mt_stock_audit_list_screen.dart:479-522`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/modern_trade/screens/mt_stock_audit_list_screen.dart#L479-L522) | **FIXED** | Wrapped `audit.name` in `Expanded` with `TextOverflow.ellipsis` so badges remain completely visible without overflow. |
| 7 | **Modern Trade Returns List Cards** | [`mt_returns_list_screen.dart:300-335`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/modern_trade/screens/mt_returns_list_screen.dart#L300-L335) | **FIXED** | Wrapped `rr.name` in `Expanded` with `TextOverflow.ellipsis`. |
| 8 | **Deliveries List Card Info** | [`deliveries_list_screen.dart:1123-1152`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/sales/screens/deliveries_list_screen.dart#L1123-L1152) | **FIXED** | Wrapped delivery staff name and zone name in `Expanded` with `maxLines: 1` and `TextOverflow.ellipsis`. |
| 9 | **Order Detail Screen – Picking Items** | [`order_detail_screen.dart:729-765`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/sales/screens/order_detail_screen.dart#L729-L765) | **FIXED** | Wrapped picking item description `Column` in `Expanded` and bounded text with `TextOverflow.ellipsis`. |
| 10 | **Route Detail Screen – Outlets Header** | [`route_detail_screen.dart:203-241`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/routes/screens/route_detail_screen.dart#L203-L241) | **FIXED** | Wrapped `ASSIGNED OUTLETS` title in `Expanded` with `TextOverflow.ellipsis` to leave room for `Add Outlet` button on 320dp screens. |
| 11 | **MT Stock Audit Create – Summary Bar** | [`mt_stock_audit_create_screen.dart:608-674`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/modern_trade/screens/mt_stock_audit_create_screen.dart#L608-L674) | **FIXED** | Replaced rigid `Row` with `Wrap(spacing: 8, runSpacing: 6)` so filter chips and selection counts wrap smoothly when filters are active. |
| 12 | **Create Outlet Screen – Photo Overlay** | [`create_outlet_screen.dart:668-691`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/routes/screens/create_outlet_screen.dart#L668-L691) | **FIXED** | Wrapped GPS coordinate text in `Expanded` with `TextOverflow.ellipsis`. |
| 13 | **App Camera Capture Dialog** | [`app_camera_capture_dialog.dart:387-408`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/core/widgets/app_camera_capture_dialog.dart#L387-L408) | **FIXED** | Replaced `Row` with `Wrap(spacing: 12, runSpacing: 8)` for camera error `Retry` and `System Camera` buttons. |

---

### Category C: Rigid `GridView`s with Hardcoded `childAspectRatio` (Bottom Overflows)

| # | Screen / Component | File & Lines | Status | Resolution Applied |
|---|-------------------|--------------|--------|--------------------|
| 14 | **Dashboard Tab Grid** | [`dashboard_tab.dart:549-557, 595-615`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/dashboard/screens/dashboard_tab.dart#L549-L557) | **FIXED** | Replaced hardcoded aspect ratio with `LayoutBuilder` calculating dynamic aspect ratio based on width and font scale (`0.92` on narrow/scaled devices, `1.02` on standard). Resized circle icon from 68 to 58. |
| 15 | **Home Dashboard Module Grid** | [`home_dashboard_screen.dart:1546-1589`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/dashboard/screens/home_dashboard_screen.dart#L1546-L1589) | **FIXED** | Wrapped in `LayoutBuilder` with adaptive aspect ratio (`1.2` on narrow/scaled screens, `1.35` on standard), compact internal padding and 40×40 circle icons on narrow devices. |

---

### Category D: Modal Bottom Sheets Missing Scrolling / `isScrollControlled: false` (Vertical Overflows)

| # | Screen / Component | File & Lines | Status | Resolution Applied |
|---|-------------------|--------------|--------|--------------------|
| 16 | **Order Creation – Stock Exceeded Warning** | [`order_creation_screen.dart:320-380`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/sales/screens/order_creation_screen.dart#L320-L380) | **FIXED** | Added `isScrollControlled: true` and wrapped sheet body in `SafeArea(child: SingleChildScrollView(...))`. |
| 17 | **Deliveries List – Filter Sheet** | [`deliveries_list_screen.dart:400-600`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/sales/screens/deliveries_list_screen.dart#L400-L600) | **FIXED** | Wrapped filter sheet content in `SafeArea(child: SingleChildScrollView(...))` with keyboard insets support. |
| 18 | **Scraps & Returns Filter Sheets** | [`scraps_list_screen.dart:242-345`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/scraps/screens/scraps_list_screen.dart#L242-L345) & [`returns_list_screen.dart:249-345`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/returns/screens/returns_list_screen.dart#L249-L345) | **FIXED** | Added `isScrollControlled: true` and wrapped content in `SafeArea(child: SingleChildScrollView(...))`. |

---

### Category E: Multi-Stepper Product Rows (Squished Stepper Inputs)

| # | Screen / Component | File & Lines | Status | Resolution Applied |
|---|-------------------|--------------|--------|--------------------|
| 19 | **Product Selection Screen – Triple Stepper Row** | [`product_selection_screen.dart:993-1023, 1100-1185`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/features/sales/screens/product_selection_screen.dart#L993-L1023) | **FIXED** | Implemented responsive `LayoutBuilder`: on narrow cards (< 340dp), `Order Qty` spans full width on row 1, while `Damaged Expired` and `Damage Quality` share row 2 (~125dp width each, preserving readable labels and full digit inputs). |
| 20 | **Order Line Card Fixed Stepper** | [`order_form_widgets.dart:133-179`](file:///home/abrar/AndroidStudioProjects/secondary_sales/lib/core/widgets/order_form_widgets.dart#L133-L179) | **FIXED** | Wrapped total amount column in `Flexible` and added `TextOverflow.ellipsis` to prevent price collisions. |
