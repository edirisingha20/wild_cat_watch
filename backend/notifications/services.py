import logging

from django.conf import settings
from django.utils import timezone

from .firebase import initialize_firebase
from core.utils.geo import calculate_distance
from sightings.selectors.sighting_selectors import get_device_tokens, get_user_locations

logger = logging.getLogger(__name__)

# Default maximum age (in minutes) for a user location to be considered fresh.
_USER_LOCATION_MAX_AGE_MINUTES = 30


def send_push_notification(token, title, body, data=None):
    """Send a single FCM push notification.

    Returns True on success.  On failure caused by an invalid / expired token
    the token row is deleted from the database so it is not retried.
    """
    try:
        app = initialize_firebase()
        if app is None:
            return False
        from firebase_admin import messaging

        message = messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
        )
        messaging.send(message)
        return True
    except Exception as exc:
        logger.exception('Failed to send FCM notification for token=%s', token)
        _remove_token_if_invalid(token, exc)
        return False


def _remove_token_if_invalid(token, exc):
    """Delete the DeviceToken row when FCM reports the token as invalid."""
    try:
        from firebase_admin.messaging import (
            SenderIdMismatchError,
            ThirdPartyAuthError,
            UnregisteredError,
        )

        if isinstance(exc, (UnregisteredError, SenderIdMismatchError, ThirdPartyAuthError)):
            from sightings.models import DeviceToken
            deleted_count, _ = DeviceToken.objects.filter(token=token).delete()
            if deleted_count:
                logger.info('Removed invalid FCM device token from DB: %s', token)
    except ImportError:
        pass
    except Exception:
        logger.exception('Error while removing invalid token=%s', token)


def send_nearby_alert(sighting):
    radius_km = float(getattr(settings, 'NEARBY_SIGHTING_RADIUS_KM', 5))
    max_age_minutes = int(getattr(
        settings, 'USER_LOCATION_MAX_AGE_MINUTES', _USER_LOCATION_MAX_AGE_MINUTES,
    ))
    user_locations = get_user_locations()
    device_tokens = get_device_tokens()

    # Build a mapping of user_id → list of FCM tokens.
    token_by_user_id = {}
    for device_token in device_tokens:
        token_by_user_id.setdefault(device_token.user_id, []).append(device_token.token)

    payload = {
        'title': 'Leopard Alert',
        'body': f'Leopard sighted near {sighting.location_name}',
        'sighting_id': sighting.id,
    }

    now = timezone.now()
    sent_count = 0
    for user_location in user_locations:
        # Skip the reporter — they already know about the sighting.
        if user_location.user_id == sighting.user_id:
            continue

        # Skip stale locations that haven't been updated recently.
        if user_location.updated_at:
            age_minutes = (now - user_location.updated_at).total_seconds() / 60
            if age_minutes > max_age_minutes:
                continue

        distance = calculate_distance(
            user_location.latitude,
            user_location.longitude,
            sighting.latitude,
            sighting.longitude,
        )

        if distance > radius_km:
            continue

        for token in token_by_user_id.get(user_location.user_id, []):
            if send_push_notification(
                token=token,
                title=payload['title'],
                body=payload['body'],
                data={'sighting_id': str(payload['sighting_id'])},
            ):
                sent_count += 1

    logger.info(
        'Nearby alert processing complete for sighting_id=%s, sent_notifications=%s',
        sighting.id,
        sent_count,
    )
    return sent_count
