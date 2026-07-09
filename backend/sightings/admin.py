from django.contrib import admin

from .models import DeviceToken, LeopardSighting, UserLocation


@admin.register(LeopardSighting)
class LeopardSightingAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'location_name', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('location_name', 'description', 'user__username')


admin.site.register(UserLocation)
admin.site.register(DeviceToken)
