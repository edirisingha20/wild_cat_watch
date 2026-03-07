import logging
import math

from django.conf import settings

from sightings.models import DeviceToken, UserLocation

logger = logging.getLogger(__name__)


def _haversine_distance_km(lat1, lng1, lat2, lng2):
    earth_radius_km = 6371.0
    lat1_rad = math.radians(lat1)
    lng1_rad = math.radians(lng1)
    lat2_rad = math.radians(lat2)
    lng2_rad = math.radians(lng2)

    dlat = lat2_rad - lat1_rad
    dlng = lng2_rad - lng1_rad

    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlng / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return earth_radius_km * c


def _send_fcm_notification(token, payload):
    try:
        from firebase_admin import messaging
    except ImportError:
        logger.warning(
            'firebase-admin is not installed; skipping FCM notification for token=%s',
            token,
        )
        return False

    try:
        message = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title=payload['title'],
                body=payload['body'],
            ),
            data={'sighting_id': str(payload['sighting_id'])},
        )
        messaging.send(message)
        return True
    except Exception:
        logger.exception('Failed to send FCM notification for token=%s', token)
        return False


def send_nearby_alert(sighting):
    radius_km = float(getattr(settings, 'NEARBY_SIGHTING_RADIUS_KM', 5))
    user_locations = UserLocation.objects.select_related('user')
    device_tokens = DeviceToken.objects.select_related('user')

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
        distance = _haversine_distance_km(
            user_location.latitude,
            user_location.longitude,
            sighting.latitude,
            sighting.longitude,
        )

        if distance > radius_km:
            continue

        for token in token_by_user_id.get(user_location.user_id, []):
            if _send_fcm_notification(token, payload):
                sent_count += 1

    logger.info(
        'Nearby alert processing complete for sighting_id=%s, sent_notifications=%s',
        sighting.id,
        sent_count,
    )
    return sent_count
