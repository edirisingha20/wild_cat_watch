from django.conf import settings
from django.db import models


class LeopardSighting(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_VERIFIED = 'verified'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_VERIFIED, 'Verified'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    latitude = models.FloatField()
    longitude = models.FloatField()
    location_name = models.CharField(max_length=255)
    image = models.ImageField(upload_to='sightings/')
    description = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['latitude']),
            models.Index(fields=['longitude']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f"Sighting #{self.pk} by {self.user} ({self.status})"


class UserLocation(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    latitude = models.FloatField()
    longitude = models.FloatField()
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user} @ ({self.latitude}, {self.longitude})"


class DeviceToken(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Token for {self.user}"
