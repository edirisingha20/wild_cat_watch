from django.contrib import admin

from .models import DeviceToken, LeopardSighting, UserLocation


admin.site.register(LeopardSighting)
admin.site.register(UserLocation)
admin.site.register(DeviceToken)
