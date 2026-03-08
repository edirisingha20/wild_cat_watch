import logging

from django.conf import settings

from .firebase import initialize_firebase
from core.utils.geo import calculate_distance
from sightings.selectors.sighting_selectors import get_device_tokens, get_user_locations

logger = logging.getLogger(__name__)


def send_push_notification(token, title, body, data=None):
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
    except Exception:
        logger.exception('Failed to send FCM notification for token=%s', token)
        return False


def send_nearby_alert(sighting):
    radius_km = float(getattr(settings, 'NEARBY_SIGHTING_RADIUS_KM', 5))
    user_locations = get_user_locations()
    device_tokens = get_device_tokens()

    token_by_user_id = {}
    for device_token in device_tokens:
        token_by_user_id.setdefault(device_token.user_id, []).append(device_token.token)

    payload = {
        'title': 'Leopard Alert',
        'body': f'Leopard sighted near {sighting.location_name}',
        'sighting_id': sighting.id,
    }

    sent_count = 0
    for user_location in user_locations:
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
