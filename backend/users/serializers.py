from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from sightings.models import DeviceToken, UserLocation


User = get_user_model()


class UserRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            'full_name',
            'birthday',
            'designation',
            'username',
            'email',
            'password',
            'password_confirm',
        ]
        extra_kwargs = {
            'full_name': {'required': True},
            'birthday': {'required': True},
            'designation': {'required': True},
            'username': {'required': True},
            'email': {'required': True},
        }

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({'password_confirm': 'Passwords do not match.'})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        return User.objects.create_user(password=password, **validated_data)


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        identifier = attrs.get('identifier', '').strip()
        password = attrs.get('password')

        if '@' in identifier:
            user = User.objects.filter(email__iexact=identifier).first()
        else:
            user = User.objects.filter(username=identifier).first()

        if user is None or not user.check_password(password):
            raise serializers.ValidationError({'detail': 'Invalid credentials.'})
        if not user.is_active:
            raise serializers.ValidationError({'detail': 'User account is inactive.'})

        refresh = RefreshToken.for_user(user)
        attrs['access'] = str(refresh.access_token)
        attrs['refresh'] = str(refresh)
        return attrs


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ['token']
        # Suppress the auto-generated UniqueValidator for the token field.
        # Deduplication is handled explicitly in create() via update_or_create,
        # so the validator would only cause false 400s on re-registration.
        extra_kwargs = {
            'token': {'validators': []},
        }

    def validate_token(self, value):
        token = value.strip()
        if not token:
            raise serializers.ValidationError('Token cannot be empty.')
        return token

    def create(self, validated_data):
        user = self.context['request'].user
        token = validated_data['token']
        # De-duplicate tokens globally and keep association with the current user.
        device_token, _ = DeviceToken.objects.update_or_create(
            token=token,
            defaults={'user': user},
        )
        return device_token


class UserLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserLocation
        fields = ['latitude', 'longitude']

    def validate_latitude(self, value):
        if value < -90 or value > 90:
            raise serializers.ValidationError('Latitude must be between -90 and 90.')
        return value

    def validate_longitude(self, value):
        if value < -180 or value > 180:
            raise serializers.ValidationError('Longitude must be between -180 and 180.')
        return value


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'full_name',
            'birthday',
            'designation',
            'date_joined',
        ]
        read_only_fields = ['id', 'username', 'email', 'date_joined']
