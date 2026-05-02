from django.core.exceptions import ImproperlyConfigured
from django.test import SimpleTestCase

from core.security import (
    PUBLIC_DEFAULT_SECRET_KEY,
    resolve_jwt_signing_key,
    resolve_secret_key,
)


class SecuritySettingsTests(SimpleTestCase):
    def test_secret_key_is_required_when_debug_is_disabled(self):
        with self.assertRaises(ImproperlyConfigured):
            resolve_secret_key('', debug=False)

    def test_public_default_secret_key_is_rejected_when_debug_is_disabled(self):
        with self.assertRaises(ImproperlyConfigured):
            resolve_secret_key(PUBLIC_DEFAULT_SECRET_KEY, debug=False)

    def test_development_secret_fallback_requires_debug(self):
        self.assertEqual(
            resolve_secret_key('', debug=True),
            PUBLIC_DEFAULT_SECRET_KEY,
        )

    def test_jwt_signing_key_rejects_public_default_when_debug_is_disabled(self):
        with self.assertRaises(ImproperlyConfigured):
            resolve_jwt_signing_key(PUBLIC_DEFAULT_SECRET_KEY, 'real-secret', debug=False)

    def test_jwt_signing_key_defaults_to_secret_key(self):
        self.assertEqual(
            resolve_jwt_signing_key('', 'real-secret', debug=False),
            'real-secret',
        )
