# 🏥 Queens Connect — Firebase Setup Guide

## Prerequisites
- Flutter SDK ≥ 3.0
- Node.js ≥ 18
- Firebase CLI + FlutterFire CLI
- Android Studio / VS Code
- A Google account

---

## Step 1: Create Firebase Project

1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add Project**
3. Name it: `medfield-pro` (or any name)
4. Disable Google Analytics (optional)
5. Click **Create Project**

---

## Step 2: Enable Firebase Services

### 2a. Authentication
1. Left sidebar → **Authentication** → **Get Started**
2. Click **Email/Password** provider
3. Toggle **Enable** → **Save**

### 2b. Firestore Database
1. Left sidebar → **Firestore Database** → **Create Database**
2. Select **Start in production mode**
3. Choose your nearest region (e.g., `asia-southeast1` for SEA)
4. Click **Enable**

### 2c. Firebase Storage
1. Left sidebar → **Storage** → **Get Started**
2. Click **Next** → choose same region as Firestore
3. Click **Done**

---

## Step 3: Add Android App to Firebase

1. In Firebase Console, click the **Android** icon (⚙️ → Project settings → Add app)
2. Enter your **Android package name**: `com.example.hospital_field_app`
   > Update this in `android/app/build.gradle` → `applicationId`
3. Download `google-services.json`
4. Place it at: `android/app/google-services.json`

---

## Step 4: Install Firebase CLI & FlutterFire CLI

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Log in to Firebase
firebase login

# Install FlutterFire CLI
dart pub global activate flutterfire_cli
```

---

## Step 5: Configure Flutter with Firebase

Run in your project root:

```bash
flutterfire configure --project=YOUR_PROJECT_ID
```

This automatically:
- Generates `lib/firebase_options.dart` with real credentials
- Updates `android/app/build.gradle` with `google-services` plugin
- Updates `android/build.gradle` with classpath

---

## Step 6: Update android/app/build.gradle

```gradle
android {
    compileSdk 34
    
    defaultConfig {
        applicationId "com.example.hospital_field_app"
        minSdk 21          // Required for geolocator
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:33.0.0')
}
```

---

## Step 7: Update android/build.gradle

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

---

## Step 8: Create FileProvider XML

Create `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <cache-path name="cache_files" path="." />
</paths>
```

---

## Step 9: Deploy Firestore Security Rules

```bash
# Deploy rules
firebase deploy --only firestore:rules

# Deploy storage rules  
firebase deploy --only storage
```

---

## Step 10: Seed Initial Data

### Create User Accounts
Run this script once from your admin panel or Firebase Console:

**Option A: Firebase Console**
1. Authentication → Add User
2. Create manager: `manager@company.com` / `password123`
3. Create field user: `user@company.com` / `password123`
4. Then in Firestore → `users` collection, create documents:

```json
// Document ID = Firebase Auth UID of manager
{
  "name": "Ahmed Rahman",
  "email": "manager@company.com",
  "role": "manager",
  "created_at": "2025-01-01T00:00:00Z"
}

// Document ID = Firebase Auth UID of field user
{
  "name": "Rahim Uddin",
  "email": "user@company.com",
  "role": "user",
  "created_at": "2025-01-01T00:00:00Z"
}
```

**Option B: Use the app's AuthService.createUser() method**
```dart
// Call once in a temporary admin screen:
await authService.createUser(
  email: 'manager@company.com',
  password: 'password123',
  name: 'Ahmed Rahman',
  role: 'manager',
);
```

### Seed Hospitals
In Firestore → `hospitals` collection, create documents:

```json
{
  "name": "Dhaka Medical College Hospital",
  "name_lower": "dhaka medical college hospital",
  "latitude": 23.7261,
  "longitude": 90.3945,
  "city": "Dhaka",
  "address": "Bakshibazar, Dhaka"
}
```

Or call `HospitalService().seedSampleHospitals()` once from the app.

---

## Step 11: Firestore Indexes

Create composite indexes in Firebase Console → Firestore → Indexes:

| Collection | Fields | Order | Query Scope |
|------------|--------|-------|-------------|
| visits | user_id ASC, timestamp DESC | — | Collection |
| visits | status ASC, timestamp DESC | — | Collection |
| hospitals | name_lower ASC | — | Collection |

Or deploy via `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "visits",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "visits",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    }
  ]
}
```

```bash
firebase deploy --only firestore:indexes
```

---

## Step 12: Build and Run

```bash
# Get packages
flutter pub get

# Run on connected Android device
flutter run

# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `google-services.json not found` | Place it at `android/app/google-services.json` |
| Location permission denied | Check AndroidManifest.xml permissions |
| Firestore permission denied | Verify security rules + user role in Firestore |
| GPS accuracy too poor | Move to open area; disable mock GPS apps |
| Image upload fails | Check Storage rules + file size < 5MB |
| `MissingPluginException` on geolocator | Run `flutter clean && flutter pub get` |

---

## Environment Variables (Production)

For production, avoid hardcoding credentials. Use:
- `--dart-define` flags for build-time variables
- Firebase App Check for API abuse prevention
- Firebase Remote Config for threshold tuning

```bash
flutter build apk \
  --dart-define=ENV=production \
  --release
```
