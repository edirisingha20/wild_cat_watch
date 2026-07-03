from django.contrib.auth.models import AbstractUser
from django.db import models


class Department(models.Model):
    name = models.CharField(max_length=255, unique=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Position(models.Model):
    department = models.ForeignKey(
        Department,
        on_delete=models.CASCADE,
        related_name='positions',
    )
    name = models.CharField(max_length=255)

    class Meta:
        ordering = ['department__name', 'name']
        constraints = [
            models.UniqueConstraint(
                fields=['department', 'name'],
                name='unique_position_name_per_department',
            )
        ]

    def __str__(self):
        return f'{self.department.name} - {self.name}'


class User(AbstractUser):
    ROLE_USER = 'user'
    ROLE_ADMIN = 'admin'
    ROLE_CHOICES = [
        (ROLE_USER, 'User'),
        (ROLE_ADMIN, 'Admin'),
    ]

    full_name = models.CharField(max_length=255, blank=True)
    birthday = models.DateField(null=True, blank=True)
    designation = models.CharField(max_length=255, blank=True)
    email = models.EmailField(unique=True)
    department = models.ForeignKey(
        Department,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='users',
    )
    position = models.ForeignKey(
        Position,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='users',
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_USER)
    # Preferred radius (km) for viewing nearby sightings and receiving alerts.
    sighting_radius_km = models.FloatField(default=5)

    def __str__(self):
        return self.username
