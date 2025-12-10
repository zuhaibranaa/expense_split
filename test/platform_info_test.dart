import 'package:flutter_test/flutter_test.dart';
import 'package:settle_up_clone/src/shared/utils/platform_info.dart';

void main() {
  group('PlatformInfo', () {
    test('should have valid platform name', () {
      // Platform name should not be null or empty
      expect(PlatformInfo.platformName, isNotEmpty);
      print('Running on: ${PlatformInfo.platformName}');
    });

    test('should return valid API base URL', () {
      final baseUrl = PlatformInfo.getDefaultApiBaseUrl();
      
      // Should be a valid HTTP URL
      expect(baseUrl, startsWith('http://'));
      expect(baseUrl, contains(':8000'));
      
      print('API Base URL: $baseUrl');
    });

    test('platform flags should be mutually exclusive for primary categories', () {
      // A platform should be either web, mobile, or desktop (not multiple)
      final categories = [
        PlatformInfo.isWeb,
        PlatformInfo.isMobile,
        PlatformInfo.isDesktop,
      ];
      
      final trueCount = categories.where((flag) => flag).length;
      expect(trueCount, equals(1), 
        reason: 'Platform should be exactly one of: web, mobile, or desktop');
    });

    test('mobile flag should match Android or iOS', () {
      if (PlatformInfo.isMobile) {
        expect(PlatformInfo.isAndroid || PlatformInfo.isIOS, isTrue);
      }
    });

    test('desktop flag should match macOS, Windows, or Linux', () {
      if (PlatformInfo.isDesktop) {
        expect(
          PlatformInfo.isMacOS || PlatformInfo.isWindows || PlatformInfo.isLinux,
          isTrue,
        );
      }
    });

    test('web platform should not report as mobile or desktop', () {
      if (PlatformInfo.isWeb) {
        expect(PlatformInfo.isMobile, isFalse);
        expect(PlatformInfo.isDesktop, isFalse);
      }
    });

    test('should provide correct base URL for web/desktop', () {
      if (PlatformInfo.isWeb || PlatformInfo.isDesktop) {
        expect(
          PlatformInfo.getDefaultApiBaseUrl(),
          equals('http://localhost:8000'),
        );
      }
    });

    test('should provide correct base URL for Android', () {
      if (PlatformInfo.isAndroid) {
        expect(
          PlatformInfo.getDefaultApiBaseUrl(),
          equals('http://10.0.2.2:8000'),
        );
      }
    });

    test('should provide correct base URL for iOS', () {
      if (PlatformInfo.isIOS) {
        expect(
          PlatformInfo.getDefaultApiBaseUrl(),
          equals('http://localhost:8000'),
        );
      }
    });
  });
}
