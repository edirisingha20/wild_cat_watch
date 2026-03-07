from rest_framework import serializers

from .models import LeopardSighting


class LeopardSightingSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeopardSighting
        fields = [
            'id',
            'description',
            'latitude',
            'longitude',
            'location_name',
            'image',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']

    def validate_latitude(self, value):
        if value < -90 or value > 90:
            raise serializers.ValidationError('Latitude must be between -90 and 90.')
        return value

    def validate_longitude(self, value):
        if value < -180 or value > 180:
            raise serializers.ValidationError('Longitude must be between -180 and 180.')
        return value


class NearbyLeopardSightingSerializer(LeopardSightingSerializer):
    distance_km = serializers.SerializerMethodField()

    class Meta(LeopardSightingSerializer.Meta):
        fields = LeopardSightingSerializer.Meta.fields + ['distance_km']

    def get_distance_km(self, obj):
        distance_map = self.context.get('distance_map', {})
        distance = distance_map.get(obj.id)
        if distance is None:
            return None
        return round(distance, 2)
