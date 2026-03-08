from django.urls import path

from .views import RegisterDeviceTokenView, RegisterUserLocationView

urlpatterns = [
    path('device-token/', RegisterDeviceTokenView.as_view(), name='register-device-token'),
    path('location/', RegisterUserLocationView.as_view(), name='register-user-location'),
]
