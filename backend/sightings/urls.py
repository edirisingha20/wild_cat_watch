from django.urls import path

from .views import ReportLeopardSightingView

urlpatterns = [
    path('report/', ReportLeopardSightingView.as_view(), name='report-leopard-sighting'),
]
