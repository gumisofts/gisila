# gisila documentation

This folder contains topic-by-topic guides for the framework. If
you're new, start with the [tutorial](../GETTING_STARTED.md) and come
back here when you need depth.

## Reading order

1. **[Getting started tutorial](../GETTING_STARTED.md)** - empty
   directory to first protected route in ~10 minutes.
2. **[Controllers and routing](controllers-and-routing.md)** - the
   `@Controller` / `@Get` / `@Post` annotations, parameter inference
   rules, and response handling.
3. **[Permissions](permissions.md)** - the five guard annotations and
   how they combine.
4. **[Authentication](authentication.md)** - `Authenticator` and
   `PermissionResolver` interfaces, plus JWT / API-key / cookie
   recipes.
5. **[Middleware](middleware.md)** - the bundled middleware
   catalogue and how to register your own (global and per-route).
6. **[Logging](logging.md)** - levels, text vs JSON formats, custom
   sinks, redaction, sampling.
7. **[Configuration](configuration.md)** - every `AppConfig` knob
   with defaults and trade-offs.
8. **[Error handling](error-handling.md)** - the `HttpException`
   hierarchy and how the framework renders it.
9. **[Testing](testing.md)** - unit and integration patterns for
   controllers, middleware, and guards.
10. **[Cookbook](cookbook.md)** - copy-paste recipes for pagination,
    file uploads, SSE, graceful shutdown, OpenTelemetry, and more.

## Cross-cutting concerns

Looking for something specific? These topics span multiple guides:

| Question                                       | Where to look                                        |
| ---------------------------------------------- | ---------------------------------------------------- |
| How do I add a `tenantId` to every request?    | [authentication](authentication.md), [middleware](middleware.md), [permissions](permissions.md) |
| How do I keep request logs out of test output? | [testing](testing.md), [configuration](configuration.md) |
| How do I version my API?                       | [cookbook](cookbook.md), [controllers-and-routing](controllers-and-routing.md) |
| How do I plug in a metrics endpoint?           | [cookbook](cookbook.md)                              |
| How does the framework pick a status code?     | [controllers-and-routing](controllers-and-routing.md), [error-handling](error-handling.md) |
| How do I redact secrets from logs?             | [logging](logging.md)                                |
| How do I write my own guard?                   | [permissions](permissions.md), [middleware](middleware.md) |
