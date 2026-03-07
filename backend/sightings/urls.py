from django.urls import path

from .views import LeopardSightingListView, NearbySightingsView, ReportLeopardSightingView

urlpatterns = [
    path('', LeopardSightingListView.as_view(), name='leopard-sightings-list'),
    path('nearby/', NearbySightingsView.as_view(), name='nearby-leopard-sightings'),
    path('report/', ReportLeopardSightingView.as_view(), name='report-leopard-sighting'),
]
