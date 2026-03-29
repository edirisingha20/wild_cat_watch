import 'dart:async';

/// Broadcast stream that emits whenever the user opens the app by tapping
/// a notification (foreground local notification or FCM background tap).
///
/// Subscribe in any screen to react — e.g. switch to the Home tab, refresh
/// the alert list.  The stream never closes for the lifetime of the app.
final StreamController<void> _notificationOpenedController =
    StreamController<void>.broadcast();

Stream<void> get notificationOpenedStream =>
    _notificationOpenedController.stream;

/// Call this to notify all subscribers that a notification was tapped.
void dispatchNotificationOpened() {
  if (!_notificationOpenedController.isClosed) {
    _notificationOpenedController.add(null);
  }
}
