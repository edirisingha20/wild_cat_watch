from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from users.models import Department, Position
from sightings.models import DeviceToken, UserLocation


User = get_user_model()


class UserApiTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.wildlife_department, _ = Department.objects.get_or_create(
            name='Wildlife Conservation Department',
        )
        cls.forest_department, _ = Department.objects.get_or_create(
            name='Forest Department',
        )
        cls.estates_department, _ = Department.objects.get_or_create(
            name='Estate Sector',
        )

        cls.wildlife_ranger, _ = Position.objects.get_or_create(
            department=cls.wildlife_department,
            name='Wildlife Ranger',
        )
        cls.forest_ranger, _ = Position.objects.get_or_create(
            department=cls.forest_department,
            name='Forester',
        )

    def test_user_registration(self):
        payload = {
            'full_name': 'Kavinda Supun',
            'birthday': '2000-05-10',
            'username': 'kavinda_test',
            'email': 'kavinda_test@example.com',
            'department_id': self.wildlife_department.id,
            'position_id': self.wildlife_ranger.id,
            'password': 'Pass1234!',
            'confirm_password': 'Pass1234!',
        }

        response = self.client.post('/api/auth/register/', payload, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(username='kavinda_test').exists())
        user = User.objects.get(username='kavinda_test')
        self.assertEqual(user.department, self.wildlife_department)
        self.assertEqual(user.position, self.wildlife_ranger)

    def test_department_lookup(self):
        response = self.client.get('/api/users/departments/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 3)
        self.assertEqual(response.data[0]['name'], 'Estate Sector')

    def test_position_lookup_filters_by_department(self):
        response = self.client.get(
            f'/api/users/positions/?department_id={self.wildlife_department.id}'
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [position['name'] for position in response.data]
        # Positions of the requested department are returned...
        self.assertIn('Wildlife Ranger', names)
        # ...and positions from other departments are excluded.
        self.assertNotIn('Forester', names)

    def test_position_lookup_requires_department(self):
        response = self.client.get('/api/users/positions/')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_registration_duplicate_email(self):
        User.objects.create_user(
            username='existing_user',
            email='dup@example.com',
            password='Pass1234!',
        )

        payload = {
            'full_name': 'Another User',
            'birthday': '2000-01-01',
            'username': 'new_user',
            'email': 'dup@example.com',
            'department_id': self.wildlife_department.id,
            'position_id': self.wildlife_ranger.id,
            'password': 'Pass1234!',
            'confirm_password': 'Pass1234!',
        }

        response = self.client.post('/api/auth/register/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_registration_password_mismatch(self):
        payload = {
            'full_name': 'Mismatch User',
            'birthday': '2000-01-01',
            'username': 'mismatch_user',
            'email': 'mismatch@example.com',
            'department_id': self.wildlife_department.id,
            'position_id': self.wildlife_ranger.id,
            'password': 'Pass1234!',
            'confirm_password': 'DifferentPass!',
        }

        response = self.client.post('/api/auth/register/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_registration_rejects_position_from_other_department(self):
        payload = {
            'full_name': 'Mismatch Position User',
            'birthday': '2000-01-01',
            'username': 'wrong_position_user',
            'email': 'wrong_position@example.com',
            'department_id': self.wildlife_department.id,
            'position_id': self.forest_ranger.id,
            'password': 'Pass1234!',
            'confirm_password': 'Pass1234!',
        }

        response = self.client.post('/api/auth/register/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('position_id', response.data)

    def test_user_login(self):
        User.objects.create_user(
            username='login_user',
            email='login_user@example.com',
            password='Pass1234!',
            full_name='Login User',
            birthday='2001-01-01',
            department=self.wildlife_department,
            position=self.wildlife_ranger,
            designation='Wildlife Ranger',
        )

        response = self.client.post(
            '/api/auth/login/',
            {'identifier': 'login_user', 'password': 'Pass1234!'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_login_with_email(self):
        User.objects.create_user(
            username='email_login_user',
            email='email_login@example.com',
            password='Pass1234!',
        )

        response = self.client.post(
            '/api/auth/login/',
            {'identifier': 'email_login@example.com', 'password': 'Pass1234!'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)

    def test_login_invalid_credentials(self):
        response = self.client.post(
            '/api/auth/login/',
            {'identifier': 'noone', 'password': 'wrong'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

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

    def test_location_update_replaces_previous(self):
        user = User.objects.create_user(
            username='loc_replace_user',
            email='loc_replace@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        self.client.post(
            '/api/users/location/',
            {'latitude': 6.0, 'longitude': 80.0},
            format='json',
        )
        self.client.post(
            '/api/users/location/',
            {'latitude': 7.0, 'longitude': 81.0},
            format='json',
        )

        self.assertEqual(UserLocation.objects.filter(user=user).count(), 1)
        loc = UserLocation.objects.get(user=user)
        self.assertAlmostEqual(loc.latitude, 7.0)

    def test_location_invalid_coordinates(self):
        user = User.objects.create_user(
            username='loc_invalid_user',
            email='loc_invalid@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        response = self.client.post(
            '/api/users/location/',
            {'latitude': 100.0, 'longitude': 80.0},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

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

    def test_device_token_deduplication(self):
        user = User.objects.create_user(
            username='dedup_user',
            email='dedup@example.com',
            password='Pass1234!',
        )
        self.client.force_authenticate(user=user)

        self.client.post(
            '/api/users/device-token/',
            {'token': 'same_token'},
            format='json',
        )
        self.client.post(
            '/api/users/device-token/',
            {'token': 'same_token'},
            format='json',
        )

        self.assertEqual(DeviceToken.objects.filter(token='same_token').count(), 1)


class UserProfileApiTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.wildlife_department, _ = Department.objects.get_or_create(
            name='Wildlife Conservation Department',
        )
        cls.wildlife_ranger, _ = Position.objects.get_or_create(
            department=cls.wildlife_department,
            name='Wildlife Ranger',
        )
        cls.wildlife_officer, _ = Position.objects.get_or_create(
            department=cls.wildlife_department,
            name='Wildlife Officer',
        )

    def setUp(self):
        self.user = User.objects.create_user(
            username='profile_user',
            email='profile_user@example.com',
            password='Pass1234!',
            full_name='Profile User',
            birthday='1995-06-15',
            department=self.wildlife_department,
            position=self.wildlife_ranger,
            designation='Wildlife Ranger',
        )
        self.client.force_authenticate(user=self.user)

    def test_get_profile(self):
        response = self.client.get('/api/users/me/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['email'], 'profile_user@example.com')
        self.assertEqual(response.data['full_name'], 'Profile User')
        self.assertEqual(response.data['birthday'], '1995-06-15')
        self.assertEqual(response.data['department']['name'], 'Wildlife Conservation Department')
        self.assertEqual(response.data['position']['name'], 'Wildlife Ranger')

    def test_update_profile(self):
        response = self.client.patch(
            '/api/users/me/',
            {
                'full_name': 'Updated Name',
                'department_id': self.wildlife_department.id,
                'position_id': self.wildlife_officer.id,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['full_name'], 'Updated Name')
        self.assertEqual(response.data['position']['name'], 'Wildlife Officer')
        # Email should not change.
        self.assertEqual(response.data['email'], 'profile_user@example.com')

    def test_update_profile_cannot_change_email(self):
        response = self.client.patch(
            '/api/users/me/',
            {'email': 'hacked@example.com'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.email, 'profile_user@example.com')

    def test_profile_unauthenticated(self):
        self.client.force_authenticate(user=None)
        response = self.client.get('/api/users/me/')

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
