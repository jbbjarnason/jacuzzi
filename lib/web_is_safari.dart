import 'package:web/web.dart' as web;

bool isSafari() {
  return web.window.navigator.userAgent.contains('Safari');
}

