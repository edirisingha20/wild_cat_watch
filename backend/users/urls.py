from django.urls import path

from .views import (
    AdminUserDetailView,
    AdminUserListView,
    DepartmentListView,
    RegisterDeviceTokenView,
    RegisterUserLocationView,
    PositionListView,
    UserProfileView,
)

urlpatterns = [
    path('departments/', DepartmentListView.as_view(), name='department-list'),
    path('positions/', PositionListView.as_view(), name='position-list'),
    path('me/', UserProfileView.as_view(), name='user-profile'),
    path('device-token/', RegisterDeviceTokenView.as_view(), name='register-device-token'),
    path('location/', RegisterUserLocationView.as_view(), name='register-user-location'),
    path('admin/users/', AdminUserListView.as_view(), name='admin-user-list'),
    path('admin/users/<int:pk>/', AdminUserDetailView.as_view(), name='admin-user-detail'),
]
