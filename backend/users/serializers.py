from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from sightings.models import DeviceToken, UserLocation

from .models import Department, Position


User = get_user_model()


class DepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Department
        fields = ['id', 'name']


class PositionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Position
        fields = ['id', 'name']


class UserRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)
    department_id = serializers.PrimaryKeyRelatedField(
        queryset=Department.objects.all(),
        source='department',
        write_only=True,
    )
    position_id = serializers.PrimaryKeyRelatedField(
        queryset=Position.objects.select_related('department').all(),
        source='position',
        write_only=True,
    )

    class Meta:
        model = User
        fields = [
            'full_name',
            'birthday',
            'username',
            'email',
            'department_id',
            'position_id',
            'password',
            'confirm_password',
        ]
        extra_kwargs = {
            'full_name': {'required': True},
            'birthday': {'required': True},
            'username': {'required': True},
            'email': {'required': True},
        }

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({'confirm_password': 'Passwords do not match.'})

        department = attrs.get('department')
        position = attrs.get('position')
        if department and position and position.department_id != department.id:
            raise serializers.ValidationError({
                'position_id': 'Selected position must belong to the selected department.'
            })
        return attrs

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        position = validated_data.get('position')
        if position and not validated_data.get('designation'):
            validated_data['designation'] = position.name
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
    department = DepartmentSerializer(read_only=True)
    position = PositionSerializer(read_only=True)
    department_id = serializers.PrimaryKeyRelatedField(
        queryset=Department.objects.all(),
        source='department',
        write_only=True,
        required=False,
        allow_null=True,
    )
    position_id = serializers.PrimaryKeyRelatedField(
        queryset=Position.objects.select_related('department').all(),
        source='position',
        write_only=True,
        required=False,
        allow_null=True,
    )

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'full_name',
            'birthday',
            'department',
            'position',
            'department_id',
            'position_id',
            'sighting_radius_km',
        ]
        read_only_fields = ['id', 'username', 'email', 'department', 'position']

    def validate_sighting_radius_km(self, value):
        if value < 1 or value > 50:
            raise serializers.ValidationError('Radius must be between 1 and 50 km.')
        return value

    def validate(self, attrs):
        department = attrs.get('department', getattr(self.instance, 'department', None))
        position = attrs.get('position', getattr(self.instance, 'position', None))

        if department and position and position.department_id != department.id:
            raise serializers.ValidationError({
                'position_id': 'Selected position must belong to the selected department.'
            })

        return attrs

    def update(self, instance, validated_data):
        department = validated_data.pop('department', instance.department)
        position = validated_data.pop('position', instance.position)

        for field in ['full_name', 'birthday', 'sighting_radius_km']:
            if field in validated_data:
                setattr(instance, field, validated_data[field])

        instance.department = department
        instance.position = position
        instance.designation = position.name if position is not None else ''

        update_fields = [
            'full_name', 'birthday', 'department', 'position', 'designation',
            'sighting_radius_km',
        ]
        instance.save(update_fields=update_fields)
        return instance
