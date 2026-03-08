from core.utils.geo import calculate_distance

from sightings.models import DeviceToken, LeopardSighting, UserLocation


def get_all_sightings():
    return LeopardSighting.objects.all()


def get_recent_sightings():
    return get_all_sightings().order_by('-created_at')


def get_nearby_sightings(latitude, longitude, radius_km):
    sightings_with_distance = []
    distance_map = {}

    for sighting in get_all_sightings():
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
