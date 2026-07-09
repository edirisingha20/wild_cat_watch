# Wild Cat Watch — Standalone Server

A zero-install version of the backend, packaged as a single Windows executable.
The person running it needs **no Python, pip, MySQL, or terminal** — they just
double-click one file.

---

## For the end user (running the server)

1. Double-click **`WildCatServer.exe`**.
2. A window opens showing:
   ```
   Wild Cat Watch server is RUNNING
   Admin panel : http://<this-pc>:8000/admin/
   API base    : http://<this-pc>:8000/api/
   ```
3. Leave the window open. The mobile app finds this server **automatically**
   as long as the phone is on the **same Wi-Fi network**.
4. To stop the server, close the window.

**First run** creates:
- a `WildCatServerData` folder next to the exe (holds the database, uploaded
  photos, and a security key), and
- a default admin login:
  - **username:** `admin`
  - **password:** `wildcat123`

Reported sightings go live immediately and push alerts are sent to nearby
users right away — no manual verification step. Log in at
`http://localhost:8000/admin/` to review or delete sightings and to manage
user accounts (create, edit, deactivate, delete).

> Change the default password after first login (Admin → Users → admin).

---

## For the developer (building the exe)

Requirements: the `backend/venv` with dependencies installed
(`pip install -r requirements.txt`) and `firebase_service_account.json` present
in `backend/`.

```powershell
cd backend
.\build_server.ps1
```

The exe is written to `dist\WildCatServer.exe`.

### How it works
- `standalone_server.py` is the entry point. It switches the database to
  **SQLite** (`DB_ENGINE=sqlite`), points data at a writable folder, runs
  migrations, creates the default admin, starts the mDNS advertiser, and serves
  the app with **waitress** on `0.0.0.0:8000`.
- Static files (admin / DRF) are served by **WhiteNoise**.
- The Django `discovery` app advertises `_wildcat._tcp` on the LAN so the phone
  app auto-discovers the server.

### ⚠️ Security
- The exe **embeds `firebase_service_account.json`** (a real admin credential).
  Only share the exe with trusted people. Never commit `dist/` to git
  (already covered by `.gitignore`).

### First-run networking
- Allow the server through Windows Firewall (once, as Administrator):
  ```powershell
  New-NetFirewallRule -DisplayName "WildCat Django 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
  New-NetFirewallRule -DisplayName "WildCat mDNS 5353"  -Direction Inbound -Protocol UDP -LocalPort 5353 -Action Allow -Profile Private
  ```
