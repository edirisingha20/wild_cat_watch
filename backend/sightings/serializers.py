from rest_framework import serializers

from .models import LeopardSighting


class LeopardSightingSerializer(serializers.ModelSerializer):
    is_mine = serializers.SerializerMethodField()

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
            'status',
            'is_mine',
        ]
        read_only_fields = ['id', 'created_at', 'status', 'is_mine']

    def get_is_mine(self, obj):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        return bool(user and user.is_authenticated and obj.user_id == user.id)

    def validate_latitude(self, value):
        if value < -90 or value > 90:
            raise serializers.ValidationError('Latitude must be between -90 and 90.')
        return value

    def validate_longitude(self, value):
        if value < -180 or value > 180:
            raise serializers.ValidationError('Longitude must be between -180 and 180.')
        return value

    def validate_image(self, value):
        max_size = 5 * 1024 * 1024
        if value.size > max_size:
            raise serializers.ValidationError('Image must be less than 5MB')

        valid_types = ['image/jpeg', 'image/png']
        content_type = getattr(value, 'content_type', None)
        if content_type not in valid_types:
            raise serializers.ValidationError('Invalid image format')

        return value


class PublicLeopardSightingSerializer(serializers.ModelSerializer):
    approximate_latitude = serializers.SerializerMethodField()
    approximate_longitude = serializers.SerializerMethodField()

    class Meta:
        model = LeopardSighting
        fields = [
            'id',
            'approximate_latitude',
            'approximate_longitude',
        ]
        read_only_fields = fields

    def get_approximate_latitude(self, obj):
        return round(float(obj.latitude), 1)

    def get_approximate_longitude(self, obj):
        return round(float(obj.longitude), 1)


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
