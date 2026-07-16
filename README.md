# 🏥 Queens Connect  Hospital Field Marketing App

A field-marketing app for pharmaceutical / medical sales teams. Field
executives log every hospital visit from their phone, and the app
independently verifies  using GPS  that they were actually at the hospital
they claim. Managers verify flagged visits, assign upcoming visits, track
each person's coverage, and export reports.

> **In one line:** it turns a visit report from a typed claim into
> location-backed evidence.

---

## Table of contents

1. [What problem it solves](#1-what-problem-it-solves)
2. [Roles](#2-roles)
3. [Core concept: how a visit is verified](#3-core-concept-how-a-visit-is-verified)
4. [Feature list](#4-feature-list)
5. [Tech stack](#5-tech-stack)
6. [Architecture & folder structure](#6-architecture--folder-structure)
7. [Data model (Firestore)](#7-data-model-firestore)
8. [Setup & running](#8-setup--running)
9. [Building a release APK](#9-building-a-release-apk)
10. [Security notes](#10-security-notes)
11. [Known limitations & roadmap](#11-known-limitations--roadmap)

---

## 1. What problem it solves

Field activity used to be reported but never verified. Three gaps:

- **Reports could not be trusted**  a visit report was just typed text.
- **No proof of presence**  no independent evidence the executive was there.
- **No visibility on coverage**  no reliable count of how many hospitals
  each person actually covered.

Queens Connect closes all three: GPS evidence per visit, manager review of
anything doubtful, and per-person coverage reporting.

---

## 2. Roles

| Role | Home screen | Can do |
|------|-------------|--------|
| **Field executive** (`user`) | Bottom nav: Log Visit · My Schedule | Log GPS-verified visits, set follow-up reminders, see their upcoming/overdue schedule, mark visits done |
| **Manager** (`manager`) | Manager Dashboard | Review & re-status visits, filter by staff/date, assign visits to staff, see the whole team's schedule, export PDF reports |

Role is a `role` field on the user document (`user` or `manager`).

---

## 3. Core concept: how a visit is verified

When an executive submits a visit, GPS is captured **by the device** at that
moment  there is no field to type a location into, and it cannot be edited.
The app then resolves where the claimed hospital actually is, in three layers:

1. **Saved hospital list**  executive picks from the database. Coordinates
   are trusted; verification is instant.
2. **Free map lookup**  if the hospital isn't saved, the app geocodes the
   typed name via OpenStreetMap Nominatim (no API key). If found nearby, it is
   verified and **auto-saved** so the next visit there is instant.
3. **Manager review**  if the map can't find it (or the match is
   suspiciously far), the visit is marked **Unrecognized** and a manager
   judges it on a map.

The distance between the executive's GPS and the hospital sets the status:

| Distance | Status | Meaning |
|----------|--------|---------|
| Under 100 m | 🟢 **Valid** | At the hospital. Accepted automatically. |
| 100–300 m | 🟡 **Warning** | Nearby but slightly off. |
| Over 300 m | 🔴 **Suspicious** | Not at the hospital. Needs explanation. |
| Can't locate | 🟣 **Unrecognized** | Manager decides manually. |

**Anti-fraud measures:** mock-GPS (fake location app) detection, a
nearest-hospital cross-check (flags when the executive is much closer to a
*different* hospital than the one claimed), and a recorded GPS-accuracy
reading.

---

## 4. Feature list

### Field executive
- Searchable hospital picker with free-text fallback
- Silent GPS capture on submit
- Optional visit photo (camera or gallery) as evidence
- **Follow-up reminders**  pick a next-appointment date and time; an
  on-device notification fires that day carrying the hospital, doctor, and note
- **My Schedule tab**  upcoming visits grouped Overdue / Today / Upcoming,
  plus completed; "Mark done" to close a visit

### Manager
- **Dashboard**  every visit, filterable by status chip (All / Unrecognized /
  Valid / Warning / Suspicious)
- **Filter**  by staff member and custom date range
- **Visit detail & review**  map with staff + hospital pins, distance,
  nearest-hospital cross-check, photo; set Valid / Warning / Suspicious with an
  optional note (decision is timestamped)
- **Assign a visit**  tell a staff member to visit a hospital on a date; lands
  in their schedule tagged *Assigned*
- **Team Schedule**  every upcoming visit across the team, grouped by date,
  showing both manager-assigned and staff self-set entries
- **Activity report**  per-staff totals (visits, distinct hospitals covered,
  valid, flagged) over a selectable date range
- **PDF export**  downloadable report with summary, per-staff table, and every
  individual visit; shareable via the system sheet

---

## 5. Tech stack

- **Flutter** (Dart, SDK ≥ 3.0.0), Material 3
- **Firebase**  Auth, Cloud Firestore, Storage
- **State management**  `provider`
- **Maps**  `flutter_map` + `latlong2` (OpenStreetMap tiles, no key)
- **Geocoding**  OpenStreetMap Nominatim via `http` (no key)
- **Notifications**  `flutter_local_notifications` + `timezone` +
  `flutter_timezone` (on-device, inexact scheduling  no exact-alarm
  permission needed)
- **PDF**  `pdf` + `printing`
- **Other**  `geolocator`, `permission_handler`, `image_picker`,
  `cached_network_image`, `intl`, `uuid`

---

## 6. Architecture & folder structure

Clean-ish layering: `core` (config/utils), `data` (models/services),
`presentation` (UI + providers).

```
lib/
├── main.dart                         # Firebase + notifications init
├── core/
│   ├── constants/app_constants.dart  # collections, statuses, thresholds
│   ├── theme/app_theme.dart          # colors, status styling
│   └── utils/distance_utils.dart     # haversine distance + status logic
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── hospital_model.dart
│   │   ├── visit_model.dart
│   │   └── schedule_model.dart       # upcoming visits (self + assigned)
│   └── services/
│       ├── auth_service.dart         # sign-in, getStaffUsers/getAllUsers
│       ├── hospital_service.dart
│       ├── visit_service.dart        # verify, submit, status update, stats
│       ├── geocoding_service.dart    # Nominatim lookup
│       ├── notification_service.dart # schedule/cancel reminders
│       ├── schedule_service.dart     # create/read/markDone, reminder sync
│       └── report_pdf_service.dart   # builds the PDF report
└── presentation/
    ├── auth/
    │   ├── auth_wrapper.dart          # routes by role
    │   └── login_screen.dart
    ├── user/
    │   ├── user_home_screen.dart      # bottom nav shell
    │   ├── visit_form_screen.dart     # log a visit
    │   └── my_schedule_screen.dart    # upcoming/overdue schedule
    ├── manager/
    │   ├── manager_dashboard_screen.dart
    │   ├── visit_detail_screen.dart
    │   ├── manager_report_screen.dart
    │   ├── manager_schedule_screen.dart
    │   └── assign_visit_screen.dart
    └── shared/
        ├── providers/                 # auth_provider, visit_form_provider
        └── widgets/common_widgets.dart
```

**Design choice  no Firestore composite indexes.** All list queries filter
*or* sort in Firestore, never both; multi-field filtering and sorting are done
in Dart. This avoids the "query requires an index" error and keeps setup
simple. Fine at this data scale.

---

## 7. Data model (Firestore)

Collections: `users`, `hospitals`, `visits`, `schedules`.

**users/{uid}**
```
name, email, role ('user' | 'manager')
```

**hospitals/{id}**
```
name, name_lower, latitude, longitude, address?, city?,
source ('database' | 'geocoded'), created_at
```

**visits/{id}**
```
user_id, user_name, manual_hospital_name, hospital_id?,
hospital_latitude?, hospital_longitude?, hospital_source,
doctor_name, purpose, notes?, gps_latitude, gps_longitude,
gps_accuracy, timestamp, photo_url?, distance_from_hospital?,
status, is_mock_gps, location_mismatch, nearest_hospital_name?,
nearest_distance_meters?, follow_up_date?, follow_up_note?,
reviewed, review_note?, reviewed_at?
```

**schedules/{id}**  (upcoming visits)
```
user_id, user_name, hospital_id?, hospital_name, doctor_name?,
scheduled_at, note?, created_by ('self' | 'manager'),
created_by_name?, status ('pending' | 'done'), done_at?,
origin_visit_id?, created_at
```

---

## 8. Setup & running

**Prerequisites:** Flutter SDK ≥ 3.0.0, a configured Firebase project, JDK 17.

```bash
# 1. Install dependencies
flutter pub get

# 2. Generate Firebase config (files are gitignored  see FIREBASE_SETUP.md)
dart pub global activate flutterfire_cli
flutterfire configure

# 3. Run
flutter run
```

Firestore must have a `hospitals` collection with accurate `latitude` /
`longitude` for trusted verification. Geocoded hospitals are added
automatically as staff visit them.

**Android build config:** `android/app/build.gradle.kts` targets Java 17
(both `compileOptions` and `kotlinOptions`), enables core-library desugaring
(required by `flutter_local_notifications`), and enables multidex.

---

## 9. Building a release APK

```bash
flutter clean
flutter build apk --release
```

If you hit *"Inconsistent JVM Target Compatibility"*, confirm
`build.gradle.kts` has both Java and Kotlin on 17. Do **not** add
`kotlin { jvmToolchain(17) }` unless a standalone JDK 17 is installed  it
makes Gradle hunt for one.

---

## 10. Security notes

See **FIREBASE_SETUP.md** for the full guide. Key points:

- Firebase config files (`firebase_options.dart`, `google-services.json`) are
  **client identifiers, not secrets**  but they're gitignored anyway.
- What actually protects the data is **Firestore Security Rules**  lock every
  collection to authenticated users, managers read-all, staff read-own. A
  ready-made ruleset is in FIREBASE_SETUP.md.
- Reminders are **on-device**: a manager-assigned visit arms its notification
  the next time the staff member opens the app, so assign at least a day ahead.

---

## 11. Known limitations & roadmap

**Current limitations**
- On-device reminders don't survive an app reinstall or a new phone.
- Manager-assigned reminders depend on the staff member opening the app.
- Small local clinics are often missing from the free map, so *Unrecognized*
  is common until the hospital list is seeded.
- App is signed with **debug keys** and uses `com.example.hospital_field_app`
   both must change before a store release.

**Possible next steps**
- Server-side push (FCM + Cloud Functions) for reliable, cross-device
  reminders  needs the paid Firebase (Blaze) plan.
- Firebase App Check to block API access from outside the real app.
- Seed a full hospital master list to cut down manual reviews.
- Proper release signing config and a company application ID.

---

*Queens Connect · internal field-marketing tool. This README contains no
secrets and is safe to commit.*
