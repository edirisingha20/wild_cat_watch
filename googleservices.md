# Leopard Sightings — Service Architecture & Codebase Integration

This document explains how the external services (**Google Maps Platform** and **Firebase Cloud Messaging**) connect to the codebase (Flutter + Django + MySQL) and how data flows through the system.

---

## 1. High-Level System Architecture

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart TB
    subgraph Mobile["📱 Flutter Mobile App"]
        UI[UI Screens]
        GM[google_maps_flutter plugin]
        GEO[geolocator plugin]
        FSDK[firebase_messaging SDK]
    end

    subgraph Backend["🖥️ Django REST Backend"]
        API[REST API Endpoints]
        AUTH[JWT Auth Layer]
        LOGIC[Business Logic<br/>Haversine Distance]
        FADMIN[Firebase Admin SDK]
    end

    subgraph Storage["🗄️ MySQL Database"]
        USERS[(Users)]
        SIGHT[(LeopardSightings)]
        LOC[(UserLocations)]
        TOK[(DeviceTokens)]
    end

    subgraph Google["☁️ Google Cloud Services"]
        MAPS[Google Maps Platform]
        FCM[Firebase Cloud Messaging]
    end

    UI -->|HTTPS REST + JWT| API
    API --> AUTH --> LOGIC
    LOGIC --> USERS & SIGHT & LOC & TOK
    GM -->|API Key| MAPS
    MAPS -->|Map Tiles| GM
    GEO -->|GPS Coordinates| UI
    FADMIN -->|Send Message| FCM
    FCM -->|Push Notification| FSDK
    FSDK -->|FCM Token| UI

    style Mobile fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    style Backend fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    style Storage fill:#fff8e1,stroke:#f9a825,color:#795548
    style Google fill:#fce4ec,stroke:#c2185b,color:#880e4f

    classDef node fill:#ffffff,stroke:#455a64,color:#212121
    class UI,GM,GEO,FSDK,API,AUTH,LOGIC,FADMIN,USERS,SIGHT,LOC,TOK,MAPS,FCM node
```

---

## 2. Where Each Service Connects in the Codebase

| Service | Codebase Location | Purpose |
|---|---|---|
| Google Maps SDK | `AndroidManifest.xml` (API Key), `Info.plist` / `AppDelegate` (iOS), `google_maps_flutter` widget | Render map tiles, markers, danger circles |
| Geolocator | Flutter — `geolocator` package | Get device GPS coordinates |
| Firebase SDK | Flutter — `firebase_messaging`, `google-services.json` / `GoogleService-Info.plist` | Receive push notifications, generate FCM token |
| Firebase Admin SDK | Django backend — service account credentials JSON | Send notifications from server → Google FCM |
| MySQL | Django ORM models | Persist users, sightings, locations, tokens |
| JWT | Django REST Framework endpoints | Authenticate every API request |

---

## 3. Google Maps — How It Connects & Works

Google Maps only **displays** geography. It stores nothing and sends nothing.

```mermaid
%%{init: {'theme':'neutral'}}%%
sequenceDiagram
    participant U as User
    participant F as Flutter App
    participant G as Google Maps Server
    participant D as Django Backend
    participant M as MySQL

    U->>F: Opens Map Screen
    F->>G: Request map tiles (with API Key)
    G-->>F: Map tiles rendered in GoogleMap() widget
    F->>F: geolocator gets GPS<br/>(lat: 7.2727, lng: 80.0544)
    F->>D: GET /api/sightings/nearby/?lat=7.27&lng=80.05
    D->>M: Query sightings near coordinates
    M-->>D: Leopard A, B, C (with coordinates)
    D-->>F: JSON list of nearby sightings
    F->>F: Draw Marker() 🔴, Circle() ⭕, User 🔵
    U->>F: Taps marker → View Leopard Details
```

**Key point:** Map tiles come from Google; **all sighting data comes from your own backend.**

### API Key Validation Flow

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart LR
    A[GoogleMap widget loads] --> B{Google checks<br/>API Key valid?}
    B -->|Yes| C[✅ Map tiles load]
    B -->|No| D[❌ Blank map]

    style A fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    style B fill:#fff3e0,stroke:#ef6c00,color:#e65100
    style C fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    style D fill:#ffebee,stroke:#c62828,color:#b71c1c
```

---

## 4. Firebase Cloud Messaging — How It Connects & Works

FCM's only job is **delivering push notifications**. It stores no app data.

### 4a. Device Token Registration (happens on app install/login)

```mermaid
%%{init: {'theme':'neutral'}}%%
sequenceDiagram
    participant F as Flutter App
    participant FB as Firebase SDK
    participant D as Django Backend
    participant M as MySQL

    F->>FB: FirebaseMessaging.instance.getToken()
    FB-->>F: FCM Token (e.g. "dklw8348df...")
    Note over F: Token = "home address"<br/>for notifications
    F->>D: POST /api/users/device-token/ (JWT)
    D->>M: Save DeviceToken<br/>(user, token, updated_at)
    Note over M: Backend now knows how<br/>to reach each user's phone
```

### 4b. Sighting Report → Notification Pipeline

```mermaid
%%{init: {'theme':'neutral'}}%%
sequenceDiagram
    participant O as Wildlife Officer
    participant F as Flutter App
    participant D as Django Backend
    participant M as MySQL
    participant FA as Firebase Admin SDK
    participant FCM as Google FCM Servers
    participant P as Nearby Phones

    O->>F: Reports leopard (photo, GPS, description)
    F->>D: POST /api/sightings/report/
    D->>M: Save LeopardSighting
    D->>M: Query all UserLocations
    D->>D: Haversine distance for each user
    Note over D: distance < 5km → eligible<br/>else → ignored
    D->>M: Get DeviceTokens of nearby users
    D->>FA: Build Message(title, body, data, token)
    FA->>FCM: messaging.send(message)
    FCM->>P: 🚨 "Leopard Alert — sighted near Maskeliya"
    P->>P: Tap notification → open Leopard Details<br/>→ view image → view map → navigate
```

### Why the Backend Can't Notify Phones Directly

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart LR
    D[Django Backend] -.->|❌ No direct route<br/>to devices| P[Android/iOS Phone]
    D -->|✅ Firebase Admin SDK| FCM[Google FCM]
    FCM -->|✅ Persistent connection<br/>maintained by OS| P

    style D fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    style FCM fill:#fce4ec,stroke:#c2185b,color:#880e4f
    style P fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
```

Google FCM acts as the **delivery network** — phones keep a persistent connection to Google's servers, not to your backend.

---

## 5. Nearby-User Filtering (Haversine)

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart TD
    S[🐆 New Sighting<br/>7.275, 80.056] --> H{Haversine distance<br/>to each UserLocation}
    H -->|Officer A — Colombo<br/>~90 km| X1[❌ Ignored]
    H -->|Officer B — Nuwara Eliya<br/>~40 km| X2[❌ Ignored]
    H -->|Officer C — Maskeliya<br/>~2 km| Y[✅ Eligible → send FCM alert]

    style S fill:#fff3e0,stroke:#ef6c00,color:#e65100
    style H fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    style X1 fill:#ffebee,stroke:#c62828,color:#b71c1c
    style X2 fill:#ffebee,stroke:#c62828,color:#b71c1c
    style Y fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
```

Without stored `UserLocation` data, the backend would have to notify **everyone** — location filtering makes alerts relevant.

---

## 6. Complete End-to-End Flow

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart TD
    A[Officer reports leopard] --> B[Flutter: POST /api/sightings/report/]
    B --> C[Django validates JWT + saves to MySQL]
    C --> D[Find nearby users via Haversine]
    D --> E[Fetch their DeviceTokens]
    E --> F[Firebase Admin SDK → Google FCM]
    F --> G[Push notification on nearby phones]
    G --> H[Officer taps notification]
    H --> I[Flutter opens Leopard Details]
    I --> J[GET sighting data from Django]
    J --> K[Google Maps renders location,<br/>marker + danger circle]
    K --> L[Officer navigates to location]

    classDef step fill:#ffffff,stroke:#455a64,color:#212121
    class A,B,C,D,E,F,G,H,I,J,K,L step
    style A fill:#fff3e0,stroke:#ef6c00,color:#e65100
    style G fill:#fce4ec,stroke:#c2185b,color:#880e4f
    style L fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
```

---

## 7. API Endpoints Map

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart LR
    subgraph Auth["🔐 Authentication"]
        A1[POST /api/auth/register/]
        A2[POST /api/auth/login/]
        A3[POST /api/token/refresh/]
        A4[GET / PATCH /api/users/me/]
    end

    subgraph Loc["📍 Location & Devices"]
        B1[POST /api/users/location/]
        B2[POST /api/users/device-token/]
    end

    subgraph Sight["🐆 Sightings"]
        C1[POST /api/sightings/report/]
        C2[GET /api/sightings/]
        C3[GET /api/sightings/nearby/]
    end

    Auth --> Loc --> Sight

    style Auth fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    style Loc fill:#fff8e1,stroke:#f9a825,color:#795548
    style Sight fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20

    classDef ep fill:#ffffff,stroke:#455a64,color:#212121
    class A1,A2,A3,A4,B1,B2,C1,C2,C3 ep
```

| Endpoint | Used By | Triggers |
|---|---|---|
| `POST /api/users/device-token/` | Flutter (Firebase SDK token) | Stores notification address |
| `POST /api/users/location/` | Flutter (geolocator) | Enables Haversine filtering |
| `POST /api/sightings/report/` | Flutter (report form) | Saves sighting **and** starts FCM pipeline |
| `GET /api/sightings/nearby/` | Flutter (map screen) | Feeds markers to Google Maps widget |

---

## 8. Responsibility Matrix

```mermaid
%%{init: {'theme':'neutral'}}%%
flowchart TB
    subgraph Presentation
        FL[Flutter<br/>UI + Camera + GPS + Notifications]
    end
    subgraph Logic
        DJ[Django REST<br/>Business Rules + Haversine + JWT]
    end
    subgraph Data
        MY[MySQL<br/>Users · Sightings · Locations · Tokens]
    end
    subgraph External["External Google Services"]
        GMP[Google Maps<br/>Visualization only]
        FC[Firebase FCM<br/>Notification delivery only]
    end

    FL <--> DJ <--> MY
    FL <--> GMP
    DJ --> FC --> FL

    style Presentation fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    style Logic fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    style Data fill:#fff8e1,stroke:#f9a825,color:#795548
    style External fill:#fce4ec,stroke:#c2185b,color:#880e4f

    classDef comp fill:#ffffff,stroke:#455a64,color:#212121
    class FL,DJ,MY,GMP,FC comp
```

| Technology | Responsibility |
|---|---|
| Flutter | Mobile UI, camera, GPS, receiving notifications |
| Django REST Framework | Business logic, API layer, notification triggering |
| MySQL | Persistent storage (users, sightings, locations, tokens) |
| Google Maps Platform | Map display and geographic visualization |
| Geolocator | Device GPS coordinates |
| Firebase Cloud Messaging | Push notification delivery network |
| Firebase Admin SDK | Secure server-side sending to FCM |
| JWT | API authentication and authorization |
| Haversine Formula | Distance calculation for nearby-user filtering |

---

## In One Sentence

> Officers report leopard sightings through the **Flutter** app → **Django** saves the report to **MySQL**, finds nearby officers with the **Haversine formula**, and pushes instant alerts via **Firebase Cloud Messaging**, while **Google Maps** visualizes sightings, danger zones, and navigation for rapid field response.