from django.urls import path

from .views import (
    LeopardSightingListView,
    MySightingsView,
    NearbySightingsView,
    ReportLeopardSightingView,
)

urlpatterns = [
    path('', LeopardSightingListView.as_view(), name='leopard-sightings-list'),
    path('mine/', MySightingsView.as_view(), name='my-leopard-sightings'),
    path('nearby/', NearbySightingsView.as_view(), name='nearby-leopard-sightings'),
    path('report/', ReportLeopardSightingView.as_view(), name='report-leopard-sighting'),
]
