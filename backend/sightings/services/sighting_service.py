import logging

from django.conf import settings

from notifications.services import send_nearby_alert
from sightings.models import LeopardSighting
from sightings.selectors.sighting_selectors import (
    get_nearby_sightings as select_nearby_sightings,
)
from sightings.selectors.sighting_selectors import get_recent_sightings as select_recent_sightings

logger = logging.getLogger(__name__)


class SightingServiceError(Exception):
    pass


class InvalidCoordinatesError(SightingServiceError):
    pass


def _validate_coordinates(latitude, longitude):
    if latitude < -90 or latitude > 90:
        raise InvalidCoordinatesError('Invalid latitude. It must be between -90 and 90.')
    if longitude < -180 or longitude > 180:
        raise InvalidCoordinatesError('Invalid longitude. It must be between -180 and 180.')


def create_sighting(user, description, latitude, longitude, image, location_name):
    _validate_coordinates(latitude, longitude)
    try:
        sighting = LeopardSighting.objects.create(
            user=user,
            description=description,
            latitude=latitude,
            longitude=longitude,
            image=image,
            location_name=location_name,
        )
    except Exception as exc:
        raise SightingServiceError(f'Failed to create sighting: {exc}') from exc

    # Notification failure must not break the sighting creation.
    try:
        send_nearby_alerts(sighting)
    except Exception:
        logger.exception(
            'Notification dispatch failed for sighting_id=%s (sighting was saved)',
            sighting.id,
        )

    return sighting


def get_recent_sightings():
    return select_recent_sightings()


def get_nearby_sightings(latitude, longitude):
    _validate_coordinates(latitude, longitude)
    radius_km = float(getattr(settings, 'NEARBY_SIGHTING_RADIUS_KM', 5))
    return select_nearby_sightings(latitude, longitude, radius_km)


def send_nearby_alerts(sighting):
    return send_nearby_alert(sighting)
