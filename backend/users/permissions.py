from rest_framework.permissions import BasePermission

from .models import User


class IsAppAdmin(BasePermission):
    """Allows access to users with the in-app admin role (or superusers)."""

    message = 'Admin privileges are required for this action.'

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (user.role == User.ROLE_ADMIN or user.is_superuser)
        )
