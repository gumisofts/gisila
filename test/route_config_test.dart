import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

void main() {
  group('RouteConfig.merge and @Public (FW-07)', () {
    const appDefault = RouteConfig(requireAuth: true, roles: {'staff'});
    const public = RouteConfig(isPublic: true);
    const methodConfig =
        RouteConfig(rateLimit: RateLimitConfig(requestsPerMinute: 10));

    test('a later layer without guards keeps the route public', () {
      // Generated chain: class config, guards, method config, middleware.
      final cfg = RouteConfig.empty
          .merge(public)
          .merge(methodConfig)
          .merge(const RouteConfig(middleware: <Middleware>[]));
      final effective = appDefault.merge(cfg);
      expect(effective.isPublic, isTrue);
      expect(effective.requireAuth, isFalse);
      expect(effective.roles, isEmpty);
      expect(effective.rateLimit?.requestsPerMinute, 10);
    });

    test('a later layer that adds a guard wins', () {
      final cfg = public.merge(const RouteConfig(permissions: {'x.read'}));
      expect(cfg.isPublic, isFalse);
      expect(cfg.permissions, {'x.read'});
      expect(public.merge(const RouteConfig(requireAuth: true)).requireAuth,
          isTrue);
    });

    test('non-public merges are unchanged', () {
      final cfg = appDefault.merge(methodConfig);
      expect(cfg.isPublic, isFalse);
      expect(cfg.requireAuth, isTrue);
      expect(cfg.roles, {'staff'});
    });
  });
}
