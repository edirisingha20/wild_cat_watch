from rest_framework import status
from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from rest_framework.views import APIView

from .serializers import NearbyLeopardSightingSerializer, LeopardSightingSerializer
from .services.sighting_service import (
    InvalidCoordinatesError,
    SightingServiceError,
    create_sighting,
    get_nearby_sightings,
    get_recent_sightings,
)


class LeopardSightingListView(ListAPIView):
    serializer_class = LeopardSightingSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return get_recent_sightings()


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

        try:
            ordered_sightings, distance_map = get_nearby_sightings(user_lat, user_lng)
        except InvalidCoordinatesError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        except SightingServiceError:
            return Response(
                {'detail': 'Failed to fetch nearby sightings.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        serializer = NearbyLeopardSightingSerializer(
            ordered_sightings,
            many=True,
            context={
                'request': request,
                'distance_map': distance_map,
            },
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


class ReportSightingRateThrottle(UserRateThrottle):
    scope = 'report_sighting'


class ReportLeopardSightingView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ReportSightingRateThrottle]

    def post(self, request):
        serializer = LeopardSightingSerializer(data=request.data)
        if serializer.is_valid():
            try:
                sighting = create_sighting(
                    user=request.user,
                    description=serializer.validated_data['description'],
                    latitude=serializer.validated_data['latitude'],
                    longitude=serializer.validated_data['longitude'],
                    image=serializer.validated_data['image'],
                    location_name=serializer.validated_data['location_name'],
                )
            except InvalidCoordinatesError as exc:
                return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
            except SightingServiceError:
                return Response(
                    {'detail': 'Failed to create sighting.'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            output = LeopardSightingSerializer(sighting, context={'request': request})
            return Response(output.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
