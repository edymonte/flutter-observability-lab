// Ponte Dart -> JS (web/obs-bridge.js) para o Datadog Browser RUM.
import 'dart:convert';
import 'dart:js_interop';

@JS('obsBridge.info')
external JSString _info();

@JS('obsBridge.addAction')
external void _addAction(JSString name, JSString attrsJson);

@JS('obsBridge.addError')
external void _addError(JSString message, JSString attrsJson);

@JS('obsBridge.open')
external void _open(JSString url);

class ObsInfo {
  final bool rumEnabled;
  final bool rumLoaded;
  final String? rumSessionId;
  final String site;
  final String appUrl;
  final String env;
  final String? error;

  const ObsInfo({
    required this.rumEnabled,
    required this.rumLoaded,
    required this.rumSessionId,
    required this.site,
    required this.appUrl,
    required this.env,
    required this.error,
  });

  static const empty = ObsInfo(
    rumEnabled: false,
    rumLoaded: false,
    rumSessionId: null,
    site: 'datadoghq.com',
    appUrl: 'https://app.datadoghq.com',
    env: 'lab',
    error: null,
  );

  factory ObsInfo.fromJson(Map<String, dynamic> j) => ObsInfo(
        rumEnabled: j['rumEnabled'] == true,
        rumLoaded: j['rumLoaded'] == true,
        rumSessionId: j['rumSessionId'] as String?,
        site: (j['site'] as String?) ?? 'datadoghq.com',
        appUrl: (j['appUrl'] as String?) ?? 'https://app.datadoghq.com',
        env: (j['env'] as String?) ?? 'lab',
        error: j['error'] as String?,
      );
}

class Obs {
  static ObsInfo info() {
    try {
      return ObsInfo.fromJson(jsonDecode(_info().toDart) as Map<String, dynamic>);
    } catch (_) {
      return ObsInfo.empty;
    }
  }

  static void action(String name, Map<String, Object?> attrs) {
    try {
      _addAction(name.toJS, jsonEncode(attrs).toJS);
    } catch (_) {}
  }

  static void error(String message, Map<String, Object?> attrs) {
    try {
      _addError(message.toJS, jsonEncode(attrs).toJS);
    } catch (_) {}
  }

  static void open(String url) {
    try {
      _open(url.toJS);
    } catch (_) {}
  }
}
