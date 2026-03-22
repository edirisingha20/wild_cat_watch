from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from sightings.models import LeopardSighting


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
        self.assertIn('distance_km', response.data[0])

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
