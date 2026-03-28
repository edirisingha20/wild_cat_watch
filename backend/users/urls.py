from django.urls import path

from .views import (
    RegisterDeviceTokenView,
    RegisterUserLocationView,
    UserProfileView,
)

urlpatterns = [
    path('me/', UserProfileView.as_view(), name='user-profile'),
    path('device-token/', RegisterDeviceTokenView.as_view(), name='register-device-token'),
    path('location/', RegisterUserLocationView.as_view(), name='register-user-location'),
]
