from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import LeopardSightingSerializer


import math
import logging

from django.conf import settings
from rest_framework import status
from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from notifications.services import send_nearby_alert

from .models import LeopardSighting
from .serializers import NearbyLeopardSightingSerializer, LeopardSightingSerializer

logger = logging.getLogger(__name__)


def haversine_distance_km(lat1, lng1, lat2, lng2):
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


class LeopardSightingListView(ListAPIView):
    queryset = LeopardSighting.objects.all().order_by('-created_at')
    serializer_class = LeopardSightingSerializer
    permission_classes = [AllowAny]


class NearbySightingsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        lat_raw = request.query_params.get('lat')
        lng_raw = request.query_params.get('lng')

        if lat_raw is None or lng_raw is None:
            return Response(
                {'detail': 'Query parameters "lat" and "lng" are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user_lat = float(lat_raw)
            user_lng = float(lng_raw)
        except (TypeError, ValueError):
            return Response(
                {'detail': 'Query parameters "lat" and "lng" must be valid numbers.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if user_lat < -90 or user_lat > 90 or user_lng < -180 or user_lng > 180:
            return Response(
                {'detail': 'Invalid coordinates. Latitude must be [-90, 90] and longitude [-180, 180].'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        radius_km = float(getattr(settings, 'NEARBY_SIGHTING_RADIUS_KM', 5))

        sightings_with_distance = []
        distance_map = {}
        for sighting in LeopardSighting.objects.all():
            distance = haversine_distance_km(
                user_lat,
                user_lng,
                sighting.latitude,
                sighting.longitude,
            )
            if distance <= radius_km:
                sightings_with_distance.append((sighting, distance))
                distance_map[sighting.id] = distance

        sightings_with_distance.sort(key=lambda item: item[1])
        ordered_sightings = [item[0] for item in sightings_with_distance]

        serializer = NearbyLeopardSightingSerializer(
            ordered_sightings,
            many=True,
            context={
                'request': request,
                'distance_map': distance_map,
            },
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


class ReportLeopardSightingView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = LeopardSightingSerializer(data=request.data)
        if serializer.is_valid():
            sighting = serializer.save(user=request.user)
            try:
                send_nearby_alert(sighting)
            except Exception:
                logger.exception(
                    'Failed to process nearby alert notifications for sighting_id=%s',
                    sighting.id,
                )
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
