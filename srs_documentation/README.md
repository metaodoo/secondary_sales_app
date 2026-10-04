# GDFL Secondary Sales & SFA Mobile Application — System Documentation

This directory contains the complete technical specifications, architectural analysis, offline mechanics, and API references for the **Secondary Sales & Sales Force Automation (SFA) Mobile Application** (`secondary_sales`).

---

## Documentation Suite Index

| Document | Purpose & Scope |
|---|---|
| 📄 **[`01_SOFTWARE_REQUIREMENTS_SPECIFICATION.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/01_SOFTWARE_REQUIREMENTS_SPECIFICATION.md)** | Full Software Requirements Specification (SRS) detailing the 18 functional modules, user roles, business rules, geofencing logic, and non-functional SLAs. |
| 🏗️ **[`02_SYSTEM_ARCHITECTURE_AND_DATA_FLOWS.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/02_SYSTEM_ARCHITECTURE_AND_DATA_FLOWS.md)** | Technical architecture, dual Dart isolate model (UI vs Background Service), inter-isolate communication, mapping engines (Barikoi + OSM), sequence diagrams, and Odoo backend module map. |
| 🔄 **[`03_OFFLINE_AND_SYNC_ARCHITECTURE.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/03_OFFLINE_AND_SYNC_ARCHITECTURE.md)** | In-depth analysis of the offline capabilities: active SQLite buffer (`locations.db`), distance threshold filtering, process-kill survival, and the full offline write queue & sync replay design. |
| 🔌 **[`04_API_ENDPOINTS_AND_DATA_MODELS_MATRIX.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/04_API_ENDPOINTS_AND_DATA_MODELS_MATRIX.md)** | Comprehensive catalog of all 21 REST API endpoints and all 26 Dart data models powering the mobile application. |
| 🚀 **[`05_MASTER_OFFLINE_ARCHITECTURE_PLAN.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/05_MASTER_OFFLINE_ARCHITECTURE_PLAN.md)** | **Master Offline Blueprint:** POS-inspired architecture, dual-UUID causal dependency resolution, graceful degradation policy, SQLite WAL concurrency, and implementation roadmap. |
| 📋 **[`06_REAL_WORLD_BANGLADESH_FMCG_OPERATIONAL_SOPS.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/06_REAL_WORLD_BANGLADESH_FMCG_OPERATIONAL_SOPS.md)** | **Real-World FMCG Operational SOPs:** 6 field sales business rules (Soft Credit, Dairy Bodli Bill Adjustment, GCR Incentive Linkage, RTM Segregation, 6 PM Godown Settlement, High-Velocity Fast Order Booking). |
| 🛡️ **[`07_ADVERSARIAL_FIELD_ATTACK_SCENARIOS_AND_DEFENSE.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/07_ADVERSARIAL_FIELD_ATTACK_SCENARIOS_AND_DEFENSE.md)** | **Adversarial Field Attacks & Defenses:** Complete technical analysis and automated test verification of 5 field sabotage attempts by reluctant sales reps (multi-tap rage clicks, process kill mid-sync, orphaned orders, empty payload poisoning, corrupt media), and under-the-hood safeguards. |



---

## Quick Reference Summary

* **Mobile Client:** Flutter SDK `^3.12.0` (Dart 3.12+), Material 3.
* **Backend ERP:** Odoo 18 Enterprise/Community with 19 custom `gdfl` modules.
* **Active Offline DB:** `sqflite: ^2.4.0` managing `locations.db` for background GNSS logging.
* **Background Process:** `flutter_background_service: ^5.0.10` running in an independent Dart isolate with an Android persistent foreground notification.
* **Geospatial & Maps:** `geolocator: ^14.0.2`, `flutter_map: ^8.3.1` (OpenStreetMap), `maplibre_gl: ^0.26.2` (Barikoi Maps Bangladesh).
* **Push Notifications:** Firebase Cloud Messaging (FCM) + Odoo Native Notification Center.
