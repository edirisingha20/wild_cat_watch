import os
import sys

from django.apps import AppConfig


class DiscoveryConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'discovery'

    def ready(self):
        # Only advertise when actually serving (runserver), not for migrate,
        # shell, tests, etc.
        if 'runserver' not in sys.argv:
            return

        # Under the autoreloader, ready() runs in both the watcher and the
        # worker process. Only advertise in the worker (RUN_MAIN == 'true'),
        # or when autoreload is disabled (--noreload).
        if os.environ.get('RUN_MAIN') != 'true' and '--noreload' not in sys.argv:
            return

        port = _parse_port(sys.argv)
        from .advertiser import start_advertiser
        start_advertiser(port)


def _parse_port(argv):
    """Extract the port from a runserver addrport argument; default 8000."""
    for arg in argv:
        if arg.startswith('-'):
            continue
        # Forms: "8000" or "0.0.0.0:8000"
        candidate = arg.rsplit(':', 1)[-1]
        if candidate.isdigit():
            return int(candidate)
    return 8000
