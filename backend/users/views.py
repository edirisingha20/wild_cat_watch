from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from sightings.models import UserLocation

from .models import Department, Position
from .permissions import IsAppAdmin

from .serializers import (
    AdminUserSerializer,
    DepartmentSerializer,
    DeviceTokenSerializer,
    LoginSerializer,
    UserProfileSerializer,
    UserLocationSerializer,
    PositionSerializer,
    UserRegisterSerializer,
)


User = get_user_model()


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


class AdminUserListView(APIView):
    """List all user accounts. Admin only."""

    permission_classes = [IsAppAdmin]

    def get(self, request):
        users = (
            User.objects.select_related('department', 'position')
            .order_by('username')
        )
        serializer = AdminUserSerializer(users, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminUserDetailView(APIView):
    """Modify or delete a user account. Admin only."""

    permission_classes = [IsAppAdmin]

    def _get_target(self, request, pk):
        user = User.objects.filter(pk=pk).first()
        if user is None:
            return None, Response(
                {'detail': 'User not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        # Superuser accounts can only be managed by other superusers (or via
        # the web admin panel), so an app admin cannot lock out the operator.
        if user.is_superuser and not request.user.is_superuser:
            return None, Response(
                {'detail': 'This account can only be managed from the web admin panel.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return user, None

    def patch(self, request, pk):
        user, error = self._get_target(request, pk)
        if error is not None:
            return error

        # Admins cannot demote or deactivate themselves; this avoids
        # accidentally losing the last active admin.
        if user.pk == request.user.pk and (
            'role' in request.data or 'is_active' in request.data
        ):
            return Response(
                {'detail': 'You cannot change your own role or active status.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = AdminUserSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        user, error = self._get_target(request, pk)
        if error is not None:
            return error

        if user.pk == request.user.pk:
            return Response(
                {'detail': 'You cannot delete your own account.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


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
