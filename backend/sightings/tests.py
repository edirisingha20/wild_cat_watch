from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from sightings.models import LeopardSighting


User = get_user_model()


def generate_test_image():
    file = BytesIO()
    image = Image.new('RGB', (100, 100), color='red')
    image.save(file, 'PNG')
    file.seek(0)
    return SimpleUploadedFile(
        'test.png',
        file.read(),
        content_type='image/png',
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
