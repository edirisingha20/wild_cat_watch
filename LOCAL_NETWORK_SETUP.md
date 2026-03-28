# 🐆 Wild Cat Watch — Local Network Setup Guide

> **Who is this for?**
> This guide is written for a beginner developer who wants to run the Wild Cat Watch system
> on their own machine and connect a real Android phone to the backend over a local WiFi network.
> Every step is explained clearly. Follow it top to bottom and you will have a working system.

---

## Table of Contents

1. [Project Overview](#1--project-overview)
2. [System Architecture](#2--system-architecture)
3. [Prerequisites](#3--prerequisites)
4. [Backend Setup (Django)](#4--backend-setup-django)
5. [Find Your Laptop IP Address](#5--find-your-laptop-ip-address)
6. [Flutter App Configuration](#6--flutter-app-configuration)
7. [Run Flutter App on Mobile](#7--run-flutter-app-on-mobile)
8. [Network & Firewall Setup](#8--network--firewall-setup)
9. [Testing the Connection](#9--testing-the-connection)
10. [Common Errors & Fixes](#10--common-errors--fixes)
11. [Alternative: ngrok](#11--alternative-ngrok)
12. [Final Checklist](#12--final-checklist)

---

## 1. 📖 Project Overview

**Wild Cat Watch** is a mobile application that allows users to report and receive alerts about leopard sightings in their area.

### How it works

| Part | Technology | Role |
|------|-----------|------|
| Backend | Django (Python) | Stores sighting data, manages users, sends push notifications |
| Mobile App | Flutter (Dart) | The Android app users carry in the field |
| Database | MySQL | Stores all data on the laptop |
| Push Notifications | Firebase (FCM) | Sends leopard alerts to nearby users |
| Maps | Google Maps | Shows sightings on a map |

### Communication flow

```
Android Phone  ──── WiFi ────►  Laptop (Django API)  ──►  MySQL Database
                                        │
                                        └──►  Firebase (notifications)
```

The mobile app talks to the Django backend using **HTTP requests** (REST API) over the local WiFi network. Both devices must be connected to **the same WiFi router**.

---

## 2. 🧱 System Architecture

### Backend — Django API (runs on your laptop)

- Written in Python using the **Django REST Framework**
- Exposes API endpoints like `/api/sightings/`, `/api/auth/login/`, etc.
- Runs on port **8000** on your laptop
- Must be started with `0.0.0.0:8000` so it listens on **all network interfaces**, not just localhost

### Mobile App — Flutter (runs on your Android phone)

- Written in Dart using the **Flutter** framework
- Makes HTTP requests to the Django backend
- Uses the **laptop's WiFi IP address** (e.g. `192.168.1.5`) to reach the backend
- Configuration is done via a `.env` file

### Network — WiFi

- Both laptop and phone must be on the **same WiFi network**
- The phone reaches the laptop using its **local IP address** (like `192.168.1.5`)
- The laptop must have its **Windows Firewall** configured to allow connections on port 8000

---

## 3. ⚙️ Prerequisites

Make sure you have all of the following installed **before** starting.

### On your laptop

| Requirement | Version / Notes | Download |
|---|---|---|
| Python | 3.10 or higher | https://www.python.org/downloads/ |
| pip | Comes with Python | — |
| MySQL Server | 8.0 recommended | https://dev.mysql.com/downloads/ |
| Flutter SDK | 3.11 or higher | https://docs.flutter.dev/get-started/install |
| Android Studio | Latest stable | https://developer.android.com/studio |
| Git | Any recent version | https://git-scm.com/ |

### On your Android phone

- Android 6.0 (Marshmallow) or higher
- **Developer Options** enabled (explained in Section 7)
- USB cable to connect to laptop (for first install)

### Network requirement

- ✅ Laptop and phone must be connected to **the same WiFi network**
- ✅ The WiFi network type on Windows must be set to **Private** (explained in Section 8)

---

## 4. 🚀 Backend Setup (Django)

### Step 1 — Open a terminal and go to the backend folder

```cmd
cd path\to\wild_cat_watch\backend
```

### Step 2 — Create and activate a Python virtual environment

**Create it** (only needed once):
```cmd
python -m venv venv
```

**Activate it** (every time you open a new terminal):
```cmd
venv\Scripts\activate
```

You will see `(venv)` appear at the start of your prompt. This means the virtual environment is active.

```
(venv) C:\...\backend>
```

> ⚠️ **IMPORTANT:** Always activate the virtual environment before running any Python or Django command.

### Step 3 — Install Python dependencies

```cmd
pip install -r requirements.txt
```

This installs Django, Django REST Framework, MySQL client, Firebase Admin SDK, and all other required packages.

### Step 4 — Configure the environment file

The backend uses a `.env` file for sensitive settings. Create it in the `backend/` folder:

```
backend/.env
```

Minimum contents:

```env
SECRET_KEY=any-long-random-string-here
DEBUG=True
ALLOWED_HOSTS=*

DB_NAME=wild_cat_watch
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_HOST=localhost
DB_PORT=3306

FIREBASE_CREDENTIALS_PATH=firebase_service_account.json
NEARBY_SIGHTING_RADIUS_KM=5
USER_LOCATION_MAX_AGE_MINUTES=30
```

> ⚠️ **IMPORTANT:** Replace `your_mysql_password` with your actual MySQL root password.

### Step 5 — Create the MySQL database

Open MySQL command line or MySQL Workbench and run:

```sql
CREATE DATABASE wild_cat_watch CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Step 6 — Run database migrations

```cmd
python manage.py migrate
```

This creates all the required tables in your MySQL database.

### Step 7 — Run the Django development server

```cmd
python manage.py runserver 0.0.0.0:8000
```

You should see:

```
Starting development server at http://0.0.0.0:8000/
Quit the server with CTRL-BREAK.
```

> ### ❓ Why `0.0.0.0` and not `localhost`?
>
> - `localhost` (or `127.0.0.1`) means: **"only accept connections from this same computer"**
> - `0.0.0.0` means: **"accept connections from ANY device on the network"**
>
> Without `0.0.0.0`, your phone will never be able to reach the backend — even if it's on the same WiFi. This is the most common mistake beginners make.

---

## 5. 🌐 Find Your Laptop IP Address

Your phone needs to know your laptop's IP address to connect to it.

### Step 1 — Open Command Prompt

Press `Win + R`, type `cmd`, press Enter.

### Step 2 — Run ipconfig

```cmd
ipconfig
```

### Step 3 — Find the correct IP address

Look through the output for the section labelled **"Wireless LAN adapter Wi-Fi"**:

```
Wireless LAN adapter Wi-Fi:

   Connection-specific DNS Suffix  . :
   IPv4 Address. . . . . . . . . . . : 192.168.1.5     ← THIS IS YOUR IP
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 192.168.1.1
```

> ⚠️ **IMPORTANT:** Ignore these adapters — they are NOT your WiFi:
> - `VirtualBox Host-Only Network`
> - `WSL` (Windows Subsystem for Linux)
> - `Bluetooth Network`
> - `vEthernet`
>
> Only use the IP address under **"Wireless LAN adapter Wi-Fi"**.

### Step 4 — Write down your IP

Your IP will look like `192.168.x.x`. Note it — you need it in the next section.

---

## 6. 📱 Flutter App Configuration

### Why `localhost` does NOT work on a real device

When you type `localhost` or `127.0.0.1` in the app, it refers to **the phone itself**, not your laptop. The phone has no idea that "localhost" means your laptop — it looks for a server running on the phone, finds nothing, and fails.

You must use your **laptop's actual IP address** on the local network.

### Device type vs URL to use

| Where is the app running? | URL to use |
|---|---|
| **Android Emulator** | `http://10.0.2.2:8000/api/` |
| **Real Android device** | `http://192.168.x.x:8000/api/` (your laptop's IP) |

> `10.0.2.2` is a special address the Android emulator uses to reach the host laptop. It does NOT work on real devices.

---

### How to set the backend URL

This project uses a `.env` file inside the Flutter app folder to configure the backend URL.

**Step 1 — Find or create the `.env` file**

It must be placed at:

```
wild_cat/  ← Flutter project root
├── lib/
├── android/
├── pubspec.yaml
└── .env          ← create this file here
```

**Step 2 — Set the API URL**

Open `.env` and add:

```env
API_URL=http://192.168.1.5:8000/api/
```

Replace `192.168.1.5` with your actual laptop IP from Section 5.

> ✅ **TIP:** Make sure the URL ends with a trailing slash `/`. Example:
> ```
> API_URL=http://192.168.1.5:8000/api/
> ```

**Step 3 — Verify `.env` is listed as a Flutter asset**

Open `pubspec.yaml` and confirm this line exists under `flutter: > assets:`:

```yaml
flutter:
  assets:
    - .env
```

If it is missing, add it and run `flutter pub get`.

---

## 7. 📲 Run Flutter App on Mobile

### Step 1 — Enable Developer Options on your Android phone

1. Open **Settings** on your phone
2. Go to **About phone**
3. Find **Build number**
4. Tap **Build number 7 times** rapidly
5. You will see: *"You are now a developer!"*

### Step 2 — Enable USB Debugging

1. Go to **Settings → Developer Options**
2. Turn on **USB Debugging**
3. Confirm the dialog if it appears

### Step 3 — Connect phone to laptop via USB

Use a USB data cable (not a charging-only cable) to connect your phone to your laptop.

When prompted on the phone: **"Allow USB debugging?"** → tap **Allow**.

### Step 4 — Verify Flutter detects your device

In the terminal (from the `wild_cat/` Flutter folder):

```cmd
flutter devices
```

You should see your phone listed, for example:

```
Kavinda's Phone (mobile) • RF8N12345XX • android-arm64 • Android 13
```

### Step 5 — Install dependencies

```cmd
flutter pub get
```

### Step 6 — Run the app on your phone

```cmd
flutter run
```

Flutter will build and install the app on your phone. This may take 2–5 minutes the first time.

> ✅ **TIP:** For faster rebuilds after the first install, you can use:
> ```cmd
> flutter run --hot
> ```

---

## 8. 🔥 Network & Firewall Setup

This is the most common reason a phone cannot reach the backend even when everything else is correct.

### Problem

Windows blocks **incoming connections** by default. When your phone tries to connect to port 8000 on your laptop, Windows Firewall silently drops the connection. The phone gets a timeout or "connection refused" error.

### Fix A — Add a Firewall Rule for Port 8000

Open Command Prompt **as Administrator** and run:

```cmd
netsh advfirewall firewall add rule name="Django Dev 8000" dir=in action=allow protocol=TCP localport=8000
```

This tells Windows: *"Allow any incoming connection on TCP port 8000."*

To remove it later when no longer needed:
```cmd
netsh advfirewall firewall delete rule name="Django Dev 8000"
```

### Fix B — Set WiFi Network Profile to Private

Windows applies stricter firewall rules to **Public** networks. If your WiFi is set to Public, incoming connections are blocked even with a firewall rule.

**Step 1 — Check your current network profile:**

```cmd
powershell -Command "Get-NetConnectionProfile"
```

Look at `NetworkCategory`. If it says `Public`, continue to Step 2.

```
Name             : SLT-4G-Kavinda
InterfaceAlias   : Wi-Fi
NetworkCategory  : Public     ← needs to be changed to Private
```

**Step 2 — Change to Private:**

```cmd
powershell -Command "Set-NetConnectionProfile -Name 'YOUR-WIFI-NAME' -NetworkCategory Private"
```

Replace `YOUR-WIFI-NAME` with the exact name shown in `Name` from the previous command.

**Step 3 — Verify the change:**

```cmd
powershell -Command "Get-NetConnectionProfile"
```

It should now show `NetworkCategory: Private`.

### Fix C — Confirm Django is listening on all interfaces

```cmd
netstat -ano | findstr :8000
```

You must see:
```
TCP    0.0.0.0:8000    0.0.0.0:0    LISTENING    ####
```

If you see `127.0.0.1:8000` instead of `0.0.0.0:8000`, Django was started without `0.0.0.0`. Stop it and restart:

```cmd
python manage.py runserver 0.0.0.0:8000
```

---

## 9. 🧪 Testing the Connection

Always test in this order — from simplest to full app.

### Test 1 — Backend works on laptop

Open your laptop browser and go to:

```
http://localhost:8000/api/sightings/
```

You should see a JSON response. If you see an error page, the backend is not running correctly. Go back to Section 4.

### Test 2 — Backend is reachable by IP (on laptop)

In your laptop browser:

```
http://192.168.1.5:8000/api/sightings/
```

(Use your actual IP.) If this works on your laptop, it means the IP and port are accessible.

### Test 3 — Backend is reachable from phone browser

On your **Android phone**, open Chrome (or any browser) and navigate to:

```
http://192.168.1.5:8000/api/sightings/
```

- ✅ You see JSON → network is working, proceed to Test 4
- ❌ Page does not load → firewall or WiFi issue, go back to Section 8

### Test 4 — Full app test

Run the Flutter app (`flutter run`) and test:

1. **Login screen** → enter credentials → should log in successfully
2. **Home screen** → should load list of sightings
3. **Map screen** → should show your location and nearby sightings
4. **Report screen** → submit a test sighting → should upload successfully

---

## 10. 🚨 Common Errors & Fixes

### ❌ Error: Connection Refused

```
DioException: Connection refused
```

**Cause:** Django is not running, or it is running on `127.0.0.1` instead of `0.0.0.0`.

**Fix:**
```cmd
python manage.py runserver 0.0.0.0:8000
```

Verify with:
```cmd
netstat -ano | findstr :8000
```
Must show `0.0.0.0:8000`.

---

### ❌ Error: Connection Timeout

```
DioException: Connection timeout
```

**Cause:** The phone is trying to connect but Windows Firewall is silently dropping the request.

**Fix:**
```cmd
netsh advfirewall firewall add rule name="Django Dev 8000" dir=in action=allow protocol=TCP localport=8000
powershell -Command "Set-NetConnectionProfile -Name 'YOUR-WIFI' -NetworkCategory Private"
```

---

### ❌ Error: Wrong IP / Cannot Find Host

```
DioException: Failed host lookup
```

**Cause:** The IP address in `.env` is wrong or outdated. Laptop IPs can change when you reconnect to WiFi.

**Fix:**
1. Run `ipconfig` again and find the current WiFi IP
2. Update `wild_cat/.env`:
   ```env
   API_URL=http://192.168.1.X:8000/api/
   ```
3. Restart the Flutter app

> ⚠️ **IMPORTANT:** Your laptop IP can change every time you reconnect to WiFi. Always re-check `ipconfig` if things stop working after a network reconnect.

---

### ❌ Error: Using `localhost` on Real Device

**Symptom:** App works on emulator but not on real phone.

**Cause:** `localhost` on a real device points to the phone itself.

**Fix:** Use your laptop's actual IP address:
```env
# WRONG
API_URL=http://localhost:8000/api/

# CORRECT (real device)
API_URL=http://192.168.1.5:8000/api/

# CORRECT (Android emulator only)
API_URL=http://10.0.2.2:8000/api/
```

---

### ❌ Error: `ALLOWED_HOSTS` Rejection

```
Invalid HTTP_HOST header: '192.168.1.5:8000'
```

**Cause:** Django's `ALLOWED_HOSTS` setting does not include your IP address.

**Fix:** In `backend/.env`, set:
```env
ALLOWED_HOSTS=*
```

This allows all hosts during development.

---

### ❌ Error: `No migrations to apply` warning about unapplied changes

```
Your models in app(s): 'sightings' have changes that are not yet reflected in a migration
```

**Fix:**
```cmd
python manage.py makemigrations
python manage.py migrate
```

---

### ❌ Error: Device Token 400 Bad Request

```
POST /api/users/device-token/ 400
```

**Cause:** The FCM device token sent from the app already exists in the database and the validator is rejecting it as a duplicate.

**Fix:** This is already fixed in the codebase. Make sure you have the latest version of `backend/users/serializers.py` with `extra_kwargs = {'token': {'validators': []}}` in `DeviceTokenSerializer`.

---

### ❌ Error: Firebase `FileNotFoundError`

```
FileNotFoundError: firebase_service_account.json
```

**Cause:** The Firebase service account credentials file is missing from the backend folder.

**Fix:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → **Project Settings → Service Accounts**
3. Click **Generate new private key** → download the JSON file
4. Rename it to `firebase_service_account.json` and place it in the `backend/` folder

---

### ❌ Error: Phone not detected by Flutter

```
No devices found
```

**Fix:**
1. Make sure USB debugging is enabled (Section 7, Step 2)
2. Unlock your phone screen
3. On the phone, accept the "Allow USB debugging?" popup if it appears
4. Try a different USB cable (charging-only cables do not work)
5. Run `flutter doctor` to check for issues

---

## 11. ⚡ Alternative: ngrok

If you cannot fix the local network connection (e.g. your WiFi router has AP Isolation that you cannot disable), you can use **ngrok** to give your backend a public URL that any device can reach.

### What is ngrok?

ngrok creates a secure tunnel from the internet to your local machine. It gives you a temporary public URL like `https://abc123.ngrok.io` that forwards all traffic to your local Django server.

### Setup

**Step 1 — Install ngrok**

Download from: https://ngrok.com/download

Or install via npm:
```cmd
npm install -g ngrok
```

**Step 2 — Run ngrok**

Make sure Django is already running on port 8000, then:
```cmd
ngrok http 8000
```

You will see output like:
```
Forwarding  https://abc123.ngrok-free.app -> http://localhost:8000
```

**Step 3 — Update Flutter `.env`**

```env
API_URL=https://abc123.ngrok-free.app/api/
```

Restart the Flutter app. The phone can now reach the backend from anywhere.

> ⚠️ **IMPORTANT:**
> - The ngrok URL changes **every time** you restart ngrok on the free plan
> - Remember to update `.env` and restart the Flutter app each time
> - ngrok is for development only, not for production use

---

## 12. ✅ Final Checklist

Before reporting "it doesn't work", go through every item in this checklist:

### Backend

- [ ] Virtual environment is activated (`(venv)` shows in terminal)
- [ ] `pip install -r requirements.txt` completed with no errors
- [ ] `backend/.env` file exists with correct database credentials
- [ ] MySQL is running and the `wild_cat_watch` database exists
- [ ] `python manage.py migrate` completed with no errors
- [ ] Django is running with `python manage.py runserver 0.0.0.0:8000`
- [ ] `netstat -ano | findstr :8000` shows `0.0.0.0:8000 LISTENING`
- [ ] `firebase_service_account.json` is present in the `backend/` folder

### Network

- [ ] Laptop and phone are connected to **the same WiFi network**
- [ ] WiFi network profile is set to **Private** (not Public)
- [ ] Firewall rule for port 8000 has been added
- [ ] Backend is reachable from **laptop browser**: `http://192.168.1.X:8000/api/sightings/`
- [ ] Backend is reachable from **phone browser**: `http://192.168.1.X:8000/api/sightings/`

### Flutter App

- [ ] `wild_cat/.env` file exists and contains `API_URL=http://192.168.1.X:8000/api/`
- [ ] The IP in `.env` matches the current output of `ipconfig`
- [ ] `flutter pub get` has been run after any `pubspec.yaml` changes
- [ ] Phone has USB debugging enabled and is detected by `flutter devices`
- [ ] App built and installed with `flutter run`

---

> 💡 **Final Tip:** The #1 most common issue is the laptop IP changing after reconnecting to WiFi.
> If the app suddenly stops working after a network change, always run `ipconfig` first and
> update the `.env` file with the new IP.

---

*Documentation for Wild Cat Watch — Local Development Setup*
