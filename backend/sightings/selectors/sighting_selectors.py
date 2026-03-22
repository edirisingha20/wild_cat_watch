import math

from core.utils.geo import calculate_distance

from sightings.models import DeviceToken, LeopardSighting, UserLocation


def get_all_sightings():
    return LeopardSighting.objects.all()


def get_recent_sightings():
    return get_all_sightings().order_by('-created_at')


def _bounding_box(latitude, longitude, radius_km):
    """Return (min_lat, max_lat, min_lng, max_lng) for a rough bounding box."""
    delta_lat = radius_km / 111.0
    delta_lng = radius_km / (111.0 * max(math.cos(math.radians(latitude)), 0.001))
    return (
        latitude - delta_lat,
        latitude + delta_lat,
        longitude - delta_lng,
        longitude + delta_lng,
    )


def get_nearby_sightings(latitude, longitude, radius_km):
    min_lat, max_lat, min_lng, max_lng = _bounding_box(latitude, longitude, radius_km)

    candidates = get_all_sightings().filter(
        latitude__gte=min_lat,
        latitude__lte=max_lat,
        longitude__gte=min_lng,
        longitude__lte=max_lng,
    )

    sightings_with_distance = []
    distance_map = {}

    for sighting in candidates:
        distance = calculate_distance(
            latitude,
            longitude,
            sighting.latitude,
            sighting.longitude,
        )
        if distance <= radius_km:
            sightings_with_distance.append((sighting, distance))
            distance_map[sighting.id] = distance

    sightings_with_distance.sort(key=lambda item: item[1])
    ordered_sightings = [item[0] for item in sightings_with_distance]
    return ordered_sightings, distance_map


def get_user_locations():
    return UserLocation.objects.select_related('user')


def get_device_tokens():
    return DeviceToken.objects.select_related('user')
