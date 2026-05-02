from django.contrib import admin

from .models import DeviceToken, LeopardSighting, UserLocation
from .services.sighting_service import verify_sighting


@admin.register(LeopardSighting)
class LeopardSightingAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'location_name', 'created_at', 'status')
    list_filter = ('status', 'created_at')
    actions = ['mark_verified']

    @admin.action(description='Mark selected sightings as verified and notify nearby users')
    def mark_verified(self, request, queryset):
        verified_count = 0
        for sighting in queryset:
            if sighting.status != LeopardSighting.STATUS_VERIFIED:
                verify_sighting(sighting)
                verified_count += 1

        self.message_user(
            request,
            f'{verified_count} sighting(s) marked as verified.',
        )


admin.site.register(UserLocation)
admin.site.register(DeviceToken)
