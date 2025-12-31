import '../shared/utils/platform_info.dart';

class Environment {
  static const String _prodApiBaseUrl = 'https://stagging-api.equisplit.click';
  static const String _prodWsBaseUrl = 'ws://stagging-api.equisplit.click';

  static const String _devApiBaseUrl = 'http://127.0.0.1:8000';
  static const String _devWsBaseUrl = 'ws://127.0.0.1:8000';

  static const String _androidDevApiBaseUrl = 'http://10.0.2.2:8000';
  static const String _androidDevWsBaseUrl = 'ws://10.0.2.2:8000';

  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');

  static String get apiBaseUrl {
    // Check if an override is provided via --dart-define
    const overrideUrl = String.fromEnvironment('API_BASE_URL');
    if (overrideUrl.isNotEmpty) {
      return overrideUrl;
    }

    if (isProduction) {
      return _prodApiBaseUrl;
    }

    // In debug mode, handle Android emulator vs others
    if (PlatformInfo.isAndroid) {
      return _androidDevApiBaseUrl;
    }

    return _devApiBaseUrl;
  }

  static String get wsBaseUrl {
    // Check if an override is provided via --dart-define
    const overrideUrl = String.fromEnvironment('WS_BASE_URL');
    if (overrideUrl.isNotEmpty) {
      return overrideUrl;
    }

    if (isProduction) {
      return _prodWsBaseUrl;
    }

    if (PlatformInfo.isAndroid) {
      return _androidDevWsBaseUrl;
    }

    return _devWsBaseUrl;
  }
}
