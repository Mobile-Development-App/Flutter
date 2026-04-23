// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void stripPasswordResetFromBrowserUrl() {
  final loc = html.window.location;
  final search = loc.search ?? '';
  final hash = loc.hash ?? '';
  if (!search.contains('oobCode') && !hash.contains('oobCode')) return;
  html.window.history.replaceState(null, html.document.title, '/');
}
