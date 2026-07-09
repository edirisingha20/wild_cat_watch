from io import BytesIO
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from sightings.models import LeopardSighting
from sightings.services.sighting_service import create_sighting


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
    @patch('sightings.services.sighting_service.send_nearby_alert')
    def test_report_sighting(self, send_nearby_alert_mock):
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

    @patch('sightings.services.sighting_service.send_nearby_alert')
    def test_report_sighting_notifies_nearby_users(self, send_nearby_alert_mock):
        user = User.objects.create_user(
            username='notify_user',
            email='notify_user@example.com',
            password='Pass1234!',
        )

        sighting = create_sighting(
            user=user,
            description='Fresh report',
            latitude=6.987,
            longitude=80.762,
            image=generate_test_image(),
            location_name='Maskeliya',
        )

        send_nearby_alert_mock.assert_called_once_with(sighting)

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
        )
        LeopardSighting.objects.create(
            user=user,
            description='Second sighting',
            latitude=7.0,
            longitude=80.8,
            location_name='Hatton',
            image=generate_test_image(),
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
        )

        response = self.client.get('/api/sightings/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        sighting = response.data['results'][0]
        self.assertEqual(float(sighting['latitude']), 6.987)
        self.assertEqual(float(sighting['longitude']), 80.762)
        self.assertIn('description', sighting)
        self.assertIn('image', sighting)
        self.assertIn('created_at', sighting)


class AdminSightingDeleteTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username='sighting_admin',
            email='sighting_admin@example.com',
            password='Pass1234!',
            role='admin',
        )
        self.reporter = User.objects.create_user(
            username='sighting_reporter',
            email='sighting_reporter@example.com',
            password='Pass1234!',
        )
        self.sighting = LeopardSighting.objects.create(
            user=self.reporter,
            description='To be moderated',
            latitude=6.987,
            longitude=80.762,
            location_name='Maskeliya',
            image=generate_test_image(),
        )

    def test_admin_can_delete_sighting(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.delete(f'/api/sightings/{self.sighting.id}/')

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(LeopardSighting.objects.filter(pk=self.sighting.pk).exists())

    def test_normal_user_cannot_delete_sighting(self):
        self.client.force_authenticate(user=self.reporter)

        response = self.client.delete(f'/api/sightings/{self.sighting.id}/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(LeopardSighting.objects.filter(pk=self.sighting.pk).exists())

    def test_unauthenticated_cannot_delete_sighting(self):
        response = self.client.delete(f'/api/sightings/{self.sighting.id}/')

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_delete_missing_sighting_returns_404(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.delete('/api/sightings/999999/')

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
