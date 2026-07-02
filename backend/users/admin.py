from django.contrib import admin

from .models import Department, Position, User


admin.site.register(User)
admin.site.register(Department)
admin.site.register(Position)
