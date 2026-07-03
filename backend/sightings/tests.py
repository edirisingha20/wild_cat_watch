from io import BytesIO
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from notifications.services import send_nearby_alert
from sightings.models import LeopardSighting
from sightings.services.sighting_service import create_sighting, verify_sighting


User = get_user_model()


def generate_test_image(fmt='PNG', content_type='image/png'):
    file = BytesIO()
    image = Image.new('RGB', (100, 100), color='red')
    image.save(file, fmt)
    file.seek(0)
    return SimpleUploadedFile(
        f'test.{fmt.lower()}',
        file.read(),
        content_type=content_type,
    )


class SightingApiTests(APITestCase):
    @override_settings(AUTO_VERIFY_SIGHTINGS=False)
    def test_report_sighting(self):
        user = User.objects.create_user(
            username='report_user',
            email='report_user@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        payload = {
            'description': 'Leopard near tea estate',
            'latitude': 6.987,
            'longitude': 80.762,
            'location_name': 'Maskeliya',
            'image': generate_test_image(),
        }

        response = self.client.post('/api/sightings/report/', payload, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(LeopardSighting.objects.count(), 1)
        self.assertEqual(LeopardSighting.objects.get().status, LeopardSighting.STATUS_PENDING)

    @override_settings(AUTO_VERIFY_SIGHTINGS=True)
    @patch('sightings.services.sighting_service.send_nearby_alert')
    def test_report_sighting_auto_verifies_and_notifies(self, send_nearby_alert_mock):
        user = User.objects.create_user(
            username='auto_verify_user',
            email='auto_verify_user@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        payload = {
            'description': 'Leopard near tea estate',
            'latitude': 6.987,
            'longitude': 80.762,
            'location_name': 'Maskeliya',
            'image': generate_test_image(),
        }

        response = self.client.post('/api/sightings/report/', payload, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sighting = LeopardSighting.objects.get()
        self.assertEqual(sighting.status, LeopardSighting.STATUS_VERIFIED)
        send_nearby_alert_mock.assert_called_once_with(sighting)

    @override_settings(AUTO_VERIFY_SIGHTINGS=False)
    @patch('sightings.services.sighting_service.send_nearby_alert')
    def test_report_sighting_does_not_notify_pending_sighting(self, send_nearby_alert_mock):
        user = User.objects.create_user(
            username='pending_notify_user',
            email='pending_notify_user@example.com',
            password='Pass1234!',
        )

        create_sighting(
            user=user,
            description='Pending report',
            latitude=6.987,
            longitude=80.762,
            image=generate_test_image(),
            location_name='Maskeliya',
        )

        send_nearby_alert_mock.assert_not_called()

    @patch('sightings.services.sighting_service.send_nearby_alert')
    def test_verifying_sighting_sends_nearby_alert(self, send_nearby_alert_mock):
        user = User.objects.create_user(
            username='verify_notify_user',
            email='verify_notify_user@example.com',
            password='Pass1234!',
        )
        sighting = LeopardSighting.objects.create(
            user=user,
            description='Verified report',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
        )

        verify_sighting(sighting)

        sighting.refresh_from_db()
        self.assertEqual(sighting.status, LeopardSighting.STATUS_VERIFIED)
        send_nearby_alert_mock.assert_called_once_with(sighting)

    @patch('notifications.services.send_push_notification')
    def test_pending_sighting_is_not_notifiable(self, send_push_notification_mock):
        user = User.objects.create_user(
            username='pending_direct_notify_user',
            email='pending_direct_notify_user@example.com',
            password='Pass1234!',
        )
        sighting = LeopardSighting.objects.create(
            user=user,
            description='Pending direct notification',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
        )

        sent_count = send_nearby_alert(sighting)

        self.assertEqual(sent_count, 0)
        send_push_notification_mock.assert_not_called()

    def test_report_sighting_unauthenticated(self):
        payload = {
            'description': 'Should fail',
            'latitude': 6.987,
            'longitude': 80.762,
            'location_name': 'Somewhere',
            'image': generate_test_image(),
        }

        response = self.client.post('/api/sightings/report/', payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_report_sighting_invalid_coordinates(self):
        user = User.objects.create_user(
            username='invalid_coord_user',
            email='invalid_coord@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        payload = {
            'description': 'Bad coords',
            'latitude': 200.0,
            'longitude': 80.0,
            'location_name': 'Nowhere',
            'image': generate_test_image(),
        }

        response = self.client.post('/api/sightings/report/', payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_report_sighting_oversized_image(self):
        user = User.objects.create_user(
            username='bigimg_user',
            email='bigimg@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        # Create an image > 5MB.
        large_content = b'\x00' * (6 * 1024 * 1024)
        large_file = SimpleUploadedFile('big.png', large_content, content_type='image/png')

        payload = {
            'description': 'Big image',
            'latitude': 6.987,
            'longitude': 80.762,
            'location_name': 'Maskeliya',
            'image': large_file,
        }

        response = self.client.post('/api/sightings/report/', payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_nearby_sightings(self):
        user = User.objects.create_user(
            username='nearby_user',
            email='nearby_user@example.com',
            password='Pass1234!',
        )

        LeopardSighting.objects.create(
            user=user,
            description='Nearby alert',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
            status=LeopardSighting.STATUS_VERIFIED,
        )

        response = self.client.get('/api/sightings/nearby/?lat=6.987&lng=80.762')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data), 1)
        sighting = response.data[0]
        self.assertIn('approximate_latitude', sighting)
        self.assertIn('approximate_longitude', sighting)
        self.assertNotIn('latitude', sighting)
        self.assertNotIn('longitude', sighting)
        self.assertNotIn('description', sighting)
        self.assertNotIn('image', sighting)
        self.assertNotIn('created_at', sighting)
        self.assertNotIn('distance_km', sighting)

    def test_authenticated_nearby_sightings_include_full_details(self):
        user = User.objects.create_user(
            username='auth_nearby_user',
            email='auth_nearby_user@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        LeopardSighting.objects.create(
            user=user,
            description='Authenticated nearby alert',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
            status=LeopardSighting.STATUS_VERIFIED,
        )

        response = self.client.get('/api/sightings/nearby/?lat=6.987&lng=80.762')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sighting = response.data[0]
        self.assertEqual(float(sighting['latitude']), 6.987)
        self.assertEqual(float(sighting['longitude']), 80.762)
        self.assertIn('description', sighting)
        self.assertIn('image', sighting)
        self.assertIn('created_at', sighting)
        self.assertIn('distance_km', sighting)

    def test_nearby_sightings_excludes_pending(self):
        user = User.objects.create_user(
            username='pending_nearby_user',
            email='pending_nearby_user@example.com',
            password='Pass1234!',
        )

        LeopardSighting.objects.create(
            user=user,
            description='Pending nearby alert',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
        )

        response = self.client.get('/api/sightings/nearby/?lat=6.987&lng=80.762')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_nearby_sightings_excludes_far(self):
        user = User.objects.create_user(
            username='far_user',
            email='far_user@example.com',
            password='Pass1234!',
        )

        LeopardSighting.objects.create(
            user=user,
            description='Far away',
            latitude=7.5,
            longitude=81.5,
            location_name='Far Away',
            image=generate_test_image(),
            status=LeopardSighting.STATUS_VERIFIED,
        )

        response = self.client.get('/api/sightings/nearby/?lat=6.0&lng=80.0')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_nearby_sightings_missing_params(self):
        response = self.client.get('/api/sightings/nearby/')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_list_sightings(self):
        user = User.objects.create_user(
            username='list_user',
            email='list_user@example.com',
            password='Pass1234!',
        )

        LeopardSighting.objects.create(
            user=user,
            description='First sighting',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
            status=LeopardSighting.STATUS_VERIFIED,
        )
        LeopardSighting.objects.create(
            user=user,
            description='Second sighting',
            latitude=7.0,
            longitude=80.8,
            location_name='Hatton',
            image=generate_test_image(),
            status=LeopardSighting.STATUS_VERIFIED,
        )

        response = self.client.get('/api/sightings/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Paginated response: {count, next, previous, results}
        self.assertEqual(response.data['count'], 2)
        self.assertEqual(len(response.data['results']), 2)
        sighting = response.data['results'][0]
        self.assertIn('approximate_latitude', sighting)
        self.assertIn('approximate_longitude', sighting)
        self.assertNotIn('latitude', sighting)
        self.assertNotIn('longitude', sighting)
        self.assertNotIn('description', sighting)
        self.assertNotIn('image', sighting)
        self.assertNotIn('created_at', sighting)

    def test_list_sightings_excludes_pending(self):
        user = User.objects.create_user(
            username='pending_list_user',
            email='pending_list_user@example.com',
            password='Pass1234!',
        )

        LeopardSighting.objects.create(
            user=user,
            description='Pending sighting',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
        )

        response = self.client.get('/api/sightings/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['count'], 0)

    def test_authenticated_list_sightings_include_full_details(self):
        user = User.objects.create_user(
            username='auth_list_user',
            email='auth_list_user@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        LeopardSighting.objects.create(
            user=user,
            description='Authenticated sighting',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
            status=LeopardSighting.STATUS_VERIFIED,
        )

        response = self.client.get('/api/sightings/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sighting = response.data['results'][0]
        self.assertEqual(float(sighting['latitude']), 6.987)
        self.assertEqual(float(sighting['longitude']), 80.762)
        self.assertIn('description', sighting)
        self.assertIn('image', sighting)
        self.assertIn('created_at', sighting)
