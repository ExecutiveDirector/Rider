# AquaGas Rider App

Flutter rider app for the AquaGas LPG delivery platform (Kenya).

## Stack

- **Flutter** + Dart
- **State management**: Riverpod (StateNotifier)
- **Networking**: Dio + Socket.IO
- **Maps**: Google Maps Flutter + Geolocator
- **Storage**: flutter_secure_storage (JWT) + Hive (prefs)
- **Push notifications**: Firebase Messaging + flutter_local_notifications
- **Background GPS**: geolocator distance filter (no wasted battery)

---

## Project Structure

```
lib/
├── main.dart                    # Entry point, service init
├── app.dart                     # MaterialApp + Riverpod ProviderScope
│
├── core/
│   ├── constants/               # Colors, strings, sizes, API/socket URLs
│   ├── config/                  # Theme, routes
│   ├── services/                # API, Socket, Location, Notification, Storage
│   └── widgets/                 # Shared UI components
│
├── data/
│   ├── models/                  # OrderModel, DriverModel, EarningsModel
│   ├── repositories/            # Auth, Order, Earnings (API calls)
│   └── providers/               # Riverpod StateNotifiers
│
└── features/
    ├── splash/                  # Token check → login or home
    ├── auth/                    # Login, OTP screens
    ├── home/                    # Dashboard, online toggle, stats
    ├── orders/                  # Active, completed, details + IncomingOrderSheet
    ├── tracking/                # Live Google Maps tracking
    ├── earnings/                # Summary + earnings list with period tabs
    ├── profile/                 # Rider info, vehicle, documents, logout
    ├── notifications/
    └── settings/
```

---

## Setup

### 1. Flutter version
```
Flutter 3.16+ / Dart 3.0+
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This generates `lib/firebase_options.dart`.

### 4. Google Maps API key

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="YOUR_GOOGLE_MAPS_KEY"/>
```

**iOS** — `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_KEY")
```

### 5. Environment variables

Pass at build time:
```bash
flutter run \
  --dart-define=API_BASE_URL=https://aquagas-backend.onrender.com/api \
  --dart-define=SOCKET_URL=https://aquagas-backend.onrender.com
```

Or set defaults directly in `lib/core/constants/api_constants.dart`.

---

## Key Architecture Decisions

### Socket (SocketService)
- Singleton, reconnects automatically (5 attempts)
- Emits: `registerDriver`, `locationUpdate`, `acceptOrder`, `rejectOrder`, `completeOrder`
- Listens: `newOrder`, `orderCancelled`, `orderUpdated`, `paymentReceived`
- Streams exposed as `Stream<T>` — providers subscribe without coupling

### Location (LocationService)
- Uses `distanceFilter: 15m` — only fires when rider moves 15+ meters
- Avoids polling every second (battery drain + Render CPU cost)
- Pushes to socket inside the stream listener

### Orders (OrderNotifier)
- Subscribes to socket streams on construction
- `incomingOrder` triggers modal bottom sheet in HomeScreen via `ref.listen`
- Auto-reject timer built into `IncomingOrderSheet` (20s countdown)

### JWT Security
- Stored in `flutter_secure_storage` (Android EncryptedSharedPreferences, iOS Keychain)
- Auto-refresh in Dio interceptor on 401 — transparent to the rest of the app

---

## MVP Screens

| Screen | Status |
|--------|--------|
| Splash (token check) | ✅ |
| Login | ✅ |
| OTP Verify | ✅ |
| Home Dashboard | ✅ |
| Active Orders | ✅ |
| Order Details | ✅ |
| Incoming Order Alert | ✅ |
| Live Tracking (Maps) | ✅ |
| Earnings | ✅ |
| Profile | ✅ |
| Completed Orders | ✅ |
| Notifications | stub |
| Settings | stub |

---

## Backend Socket Events Expected

### Driver → Backend
```json
{ "event": "registerDriver", "data": { "driverId": 1 } }
{ "event": "locationUpdate", "data": { "driverId": 1, "lat": -1.29, "lng": 36.82, "orderId": "abc" } }
{ "event": "acceptOrder", "data": { "orderId": "abc", "driverId": 1 } }
{ "event": "rejectOrder", "data": { "orderId": "abc", "driverId": 1, "reason": "..." } }
{ "event": "completeOrder", "data": { "orderId": "abc", "driverId": 1, "completedAt": "..." } }
```

### Backend → Driver
```json
{ "event": "newOrder", "data": { "id": "abc", "customerName": "...", ... } }
{ "event": "orderCancelled", "data": { "orderId": "abc" } }
{ "event": "orderUpdated", "data": { ...orderFields } }
{ "event": "paymentReceived", "data": { "orderId": "abc", "amount": 1500 } }
```

---

## Post-MVP Roadmap
- Route optimization (Google Directions API)
- Rider ratings system
- Rider wallet + M-Pesa payout
- Offline mode with Hive queue
- Dark mode
- Voice navigation
