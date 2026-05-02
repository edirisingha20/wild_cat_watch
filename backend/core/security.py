from django.core.exceptions import ImproperlyConfigured


PUBLIC_DEFAULT_SECRET_KEY = 'django-insecure-change-this-for-production'


def resolve_secret_key(secret_key, debug):
    configured_secret = (secret_key or '').strip()

    if configured_secret and configured_secret != PUBLIC_DEFAULT_SECRET_KEY:
        return configured_secret

    if debug:
        return configured_secret or PUBLIC_DEFAULT_SECRET_KEY

    raise ImproperlyConfigured(
        'SECRET_KEY must be set to a unique non-public value when DEBUG is disabled.'
    )


def resolve_jwt_signing_key(jwt_signing_key, secret_key, debug):
    configured_signing_key = (jwt_signing_key or '').strip()

    if configured_signing_key and configured_signing_key != PUBLIC_DEFAULT_SECRET_KEY:
        return configured_signing_key

    if configured_signing_key == PUBLIC_DEFAULT_SECRET_KEY and not debug:
        raise ImproperlyConfigured(
            'JWT_SIGNING_KEY must not use the public development fallback when DEBUG is disabled.'
        )

    return secret_key
