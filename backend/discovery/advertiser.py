"""LAN service advertising for the Wild Cat Watch backend.

Broadcasts an mDNS / DNS-SD service (``_wildcat._tcp.local.``) so the Flutter
app can find this backend automatically on the local Wi-Fi network without a
hard-coded IP address.  A background thread re-registers the service if the
laptop's LAN IP changes (e.g. after switching Wi-Fi networks), so the app keeps
working across network changes.
"""

import atexit
import logging
import socket
import threading
import time

logger = logging.getLogger(__name__)

SERVICE_TYPE = '_wildcat._tcp.local.'
SERVICE_NAME = 'WildCatBackend._wildcat._tcp.local.'
SERVICE_SERVER = 'wildcat-backend.local.'

# Guards against starting the advertiser more than once in a single process.
_started = False
_lock = threading.Lock()


def get_lan_ip():
    """Return the primary LAN IPv4 address, or 127.0.0.1 if offline."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # No packets are actually sent; this just picks the outbound interface.
        sock.connect(('8.8.8.8', 80))
        return sock.getsockname()[0]
    except OSError:
        return '127.0.0.1'
    finally:
        sock.close()


def _build_service_info(ip, port):
    from zeroconf import ServiceInfo

    return ServiceInfo(
        SERVICE_TYPE,
        SERVICE_NAME,
        addresses=[socket.inet_aton(ip)],
        port=port,
        properties={'path': '/api/'},
        server=SERVICE_SERVER,
    )


def start_advertiser(port):
    """Register the mDNS service and keep it fresh in a background thread."""
    global _started
    with _lock:
        if _started:
            return
        _started = True

    try:
        from zeroconf import Zeroconf
    except ImportError:
        logger.warning(
            'zeroconf is not installed; LAN auto-discovery is disabled. '
            'Install it with "pip install zeroconf".'
        )
        return

    zeroconf = Zeroconf()
    current_ip = get_lan_ip()
    info = _build_service_info(current_ip, port)

    try:
        zeroconf.register_service(info)
        logger.info('mDNS service advertised: %s at %s:%s', SERVICE_NAME, current_ip, port)
    except Exception:
        logger.exception('Failed to register mDNS service; auto-discovery disabled.')
        zeroconf.close()
        return

    state = {'ip': current_ip, 'info': info}

    def _monitor():
        """Re-advertise with a new address when the LAN IP changes."""
        while True:
            time.sleep(5)
            new_ip = get_lan_ip()
            if new_ip != state['ip'] and new_ip != '127.0.0.1':
                logger.info('LAN IP changed %s -> %s; re-advertising.', state['ip'], new_ip)
                new_info = _build_service_info(new_ip, port)
                try:
                    zeroconf.update_service(new_info)
                    state['ip'] = new_ip
                    state['info'] = new_info
                except Exception:
                    logger.exception('Failed to update mDNS service for new IP.')

    monitor = threading.Thread(target=_monitor, name='mdns-ip-monitor', daemon=True)
    monitor.start()

    def _cleanup():
        try:
            zeroconf.unregister_service(state['info'])
        finally:
            zeroconf.close()
            logger.info('mDNS service unregistered.')

    atexit.register(_cleanup)
