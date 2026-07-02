from django.urls import path

from .views import (
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
]
