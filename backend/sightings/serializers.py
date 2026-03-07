from rest_framework import serializers

from .models import LeopardSighting


class LeopardSightingSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeopardSighting
        fields = [
            'id',
            'latitude',
            'longitude',
            'image',
            'description',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']
