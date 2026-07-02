from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from sightings.models import UserLocation

from .models import Department, Position

from .serializers import (
    DepartmentSerializer,
    DeviceTokenSerializer,
    LoginSerializer,
    UserProfileSerializer,
    UserLocationSerializer,
    PositionSerializer,
    UserRegisterSerializer,
)


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = UserRegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return Response(
                {
                    'id': user.id,
                    'full_name': user.full_name,
                    'username': user.username,
                    'email': user.email,
                    'birthday': user.birthday,
                    'department': DepartmentSerializer(user.department).data if user.department else None,
                    'position': PositionSerializer(user.position).data if user.position else None,
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            return Response(
                {
                    'access': serializer.validated_data['access'],
                    'refresh': serializer.validated_data['refresh'],
                },
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RegisterDeviceTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenSerializer(
            data=request.data,
            context={'request': request},
        )
        if serializer.is_valid():
            serializer.save()
            return Response({'detail': 'Device token registered.'}, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RegisterUserLocationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = UserLocationSerializer(data=request.data)
        if serializer.is_valid():
            user_location, _ = UserLocation.objects.update_or_create(
                user=request.user,
                defaults=serializer.validated_data,
            )
            output = UserLocationSerializer(user_location).data
            return Response(output, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request):
        serializer = UserProfileSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        if serializer.is_valid():
            serializer.save()
            return Response(UserProfileSerializer(request.user).data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DepartmentListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        serializer = DepartmentSerializer(Department.objects.all(), many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class PositionListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        department_id = request.query_params.get('department_id')
        if not department_id:
            return Response(
                {'department_id': 'This query parameter is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        department = Department.objects.filter(pk=department_id).first()
        if department is None:
            return Response(
                {'department_id': 'Invalid department.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = PositionSerializer(
            Position.objects.filter(department=department).select_related('department'),
            many=True,
        )
        return Response(serializer.data, status=status.HTTP_200_OK)
