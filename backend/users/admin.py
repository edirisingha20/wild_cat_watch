from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

from .models import Department, Position, User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    """Full user management for admins: create, modify, deactivate and delete
    users with proper password hashing, plus the app-specific profile fields."""

    list_display = (
        'id',
        'username',
        'email',
        'full_name',
        'role',
        'department',
        'position',
        'is_active',
        'date_joined',
    )
    list_filter = ('role', 'is_active', 'is_staff', 'department')
    search_fields = ('username', 'email', 'full_name')
    ordering = ('username',)

    fieldsets = DjangoUserAdmin.fieldsets + (
        (
            'Wild Cat Watch profile',
            {
                'fields': (
                    'full_name',
                    'birthday',
                    'designation',
                    'department',
                    'position',
                    'role',
                    'sighting_radius_km',
                ),
            },
        ),
    )
    add_fieldsets = DjangoUserAdmin.add_fieldsets + (
        (
            'Wild Cat Watch profile',
            {
                'fields': ('email', 'full_name', 'role', 'department', 'position'),
            },
        ),
    )

    actions = ['activate_users', 'deactivate_users']

    @admin.action(description='Activate selected users')
    def activate_users(self, request, queryset):
        updated = queryset.update(is_active=True)
        self.message_user(request, f'{updated} user(s) activated.')

    @admin.action(description='Deactivate selected users (blocks login)')
    def deactivate_users(self, request, queryset):
        updated = queryset.exclude(pk=request.user.pk).update(is_active=False)
        self.message_user(request, f'{updated} user(s) deactivated.')


admin.site.register(Department)
admin.site.register(Position)
