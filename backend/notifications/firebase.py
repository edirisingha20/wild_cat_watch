import logging

from django.conf import settings

logger = logging.getLogger(__name__)


def initialize_firebase():
    """Initialize Firebase Admin once for the process."""
    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        logger.warning('firebase-admin is not installed; Firebase initialization skipped.')
        return None

    if firebase_admin._apps:
        return firebase_admin.get_app()

    credentials_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None)
    if not credentials_path:
        credentials_path = str(settings.BASE_DIR / 'firebase_service_account.json')

    cred = credentials.Certificate(credentials_path)
    app = firebase_admin.initialize_app(cred)
    logger.info('Firebase initialized with credentials at %s', credentials_path)
    return app
