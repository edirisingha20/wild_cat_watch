from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from sightings.models import DeviceToken, UserLocation


User = get_user_model()


class UserApiTests(APITestCase):
    def test_user_registration(self):
        payload = {
            'full_name': 'Kavinda Supun',
            'birthday': '2000-05-10',
            'designation': 'Software Engineer',
            'username': 'kavinda_test',
            'email': 'kavinda_test@example.com',
            'password': 'Pass1234!',
            'password_confirm': 'Pass1234!',
        }

        response = self.client.post('/api/auth/register/', payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(username='kavinda_test').exists())

    def test_user_login(self):
        User.objects.create_user(
            username='login_user',
            email='login_user@example.com',
            password='Pass1234!',
            full_name='Login User',
            designation='Tester',
            birthday='2001-01-01',
        )

        response = self.client.post(
            '/api/auth/login/',
            {'identifier': 'login_user', 'password': 'Pass1234!'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_user_location_update(self):
        user = User.objects.create_user(
            username='location_user',
            email='location_user@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        response = self.client.post(
            '/api/users/location/',
            {'latitude': 6.987, 'longitude': 80.762},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(UserLocation.objects.filter(user=user).exists())

    def test_device_token_registration(self):
        user = User.objects.create_user(
            username='token_user',
            email='token_user@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        response = self.client.post(
            '/api/users/device-token/',
            {'token': 'fcm_device_token_123'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(DeviceToken.objects.filter(user=user, token='fcm_device_token_123').exists())
