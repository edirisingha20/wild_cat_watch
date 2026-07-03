"""Zero-install standalone launcher for the Wild Cat Watch backend.

Packaged with PyInstaller into a single WildCatServer.exe. Double-clicking it:
  1. creates a writable data folder next to the exe (SQLite DB + uploaded media),
  2. applies database migrations,
  3. creates a default admin account on first run,
  4. advertises itself on the LAN (mDNS) so the mobile app finds it automatically,
  5. serves the API + admin on http://<this-pc>:8000 via a production WSGI server.

The person running it never needs Python, pip, MySQL, or a terminal.
"""

import os
import socket
import sys
from pathlib import Path

# Default admin created on first run (shown in the console).
DEFAULT_ADMIN_USERNAME = 'admin'
DEFAULT_ADMIN_EMAIL = 'admin@wildcat.local'
DEFAULT_ADMIN_PASSWORD = 'wildcat123'

PORT = 8000


def base_dir() -> Path:
    """Folder the exe lives in (or the backend/ folder when run from source)."""
    if getattr(sys, 'frozen', False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def bundle_dir() -> Path:
    """Folder where PyInstaller unpacks bundled data files at runtime."""
    if getattr(sys, 'frozen', False):
        return Path(sys._MEIPASS)  # type: ignore[attr-defined]
    return Path(__file__).resolve().parent


def load_or_create_secret(data_dir: Path) -> str:
    """Persist a stable SECRET_KEY so JWTs survive restarts."""
    key_file = data_dir / 'secret.key'
    if key_file.exists():
        return key_file.read_text(encoding='utf-8').strip()
    from django.core.management.utils import get_random_secret_key
    secret = get_random_secret_key()
    key_file.write_text(secret, encoding='utf-8')
    return secret


def configure_environment() -> Path:
    data_dir = base_dir() / 'WildCatServerData'
    data_dir.mkdir(parents=True, exist_ok=True)
    (data_dir / 'media').mkdir(exist_ok=True)

    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
    os.environ['WILDCAT_STANDALONE'] = '1'
    os.environ['WILDCAT_DATA_DIR'] = str(data_dir)
    os.environ['DB_ENGINE'] = 'sqlite'
    os.environ['DEBUG'] = 'False'
    os.environ['ALLOWED_HOSTS'] = '*'

    # SECRET_KEY must be set before django imports settings.
    os.environ['SECRET_KEY'] = load_or_create_secret(data_dir)

    # Firebase credentials (for push notifications). Prefer an external file
    # placed next to the exe (lets you rotate creds without rebuilding); fall
    # back to the copy bundled inside the exe.
    external_cred = base_dir() / 'firebase_service_account.json'
    bundled_cred = bundle_dir() / 'firebase_service_account.json'
    if external_cred.exists():
        os.environ['FIREBASE_CREDENTIALS_PATH'] = str(external_cred)
    elif bundled_cred.exists():
        os.environ['FIREBASE_CREDENTIALS_PATH'] = str(bundled_cred)

    return data_dir


def create_default_admin() -> None:
    from django.contrib.auth import get_user_model
    user_model = get_user_model()
    if user_model.objects.filter(is_superuser=True).exists():
        return
    user_model.objects.create_superuser(
        username=DEFAULT_ADMIN_USERNAME,
        email=DEFAULT_ADMIN_EMAIL,
        password=DEFAULT_ADMIN_PASSWORD,
    )
    print(f'  Created admin account: {DEFAULT_ADMIN_USERNAME} / {DEFAULT_ADMIN_PASSWORD}')


def local_ip() -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(('8.8.8.8', 80))
        return sock.getsockname()[0]
    except OSError:
        return '127.0.0.1'
    finally:
        sock.close()


def main() -> None:
    # Ensure the console shows messages immediately (unbuffered).
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass

    print('Starting Wild Cat Watch server...')
    configure_environment()

    import django
    django.setup()

    from django.core.management import call_command
    print('  Preparing database...')
    call_command('migrate', interactive=False, verbosity=0)

    create_default_admin()

    # Advertise on the LAN so phones discover this server automatically.
    from discovery.advertiser import start_advertiser
    start_advertiser(PORT)

    from core.wsgi import application
    from waitress import serve

    ip = local_ip()
    print('')
    print('=' * 52)
    print('  Wild Cat Watch server is RUNNING')
    print(f'  Admin panel : http://{ip}:{PORT}/admin/')
    print(f'  API base    : http://{ip}:{PORT}/api/')
    print('  The mobile app will find this server automatically')
    print('  as long as the phone is on the same Wi-Fi.')
    print('')
    print('  Keep this window open. Close it to stop the server.')
    print('=' * 52)
    print('')

    serve(application, host='0.0.0.0', port=PORT, threads=8)


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:  # noqa: BLE001 - surface any startup error to the user
        import traceback
        print('\nThe server failed to start:\n')
        traceback.print_exc()
        print(f'\nError: {exc}')
        input('\nPress Enter to close...')
        sys.exit(1)
