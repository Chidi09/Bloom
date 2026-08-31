# Changelog

## 0.2.1 - 2026-08-31

### Added
* Route groups, explicit OPTIONS routes, route-aware Allow headers, 405 responses, and automatic OPTIONS handling.
* Streaming multipart form-data fields and files with request-size enforcement.

## 0.2.0 - 2026-08-24

### Added
* Streaming response bodies.
* Backend-for-Frontend support (dev proxy, RPC mount, env split).

## 0.1.0

Initial release — Flutter-free extraction of `bloom_framework`'s
`bloom_server.dart` barrel (BloomApiRouter, BloomRequest/BloomResponse,
BloomMiddleware, env config, DI container/scope). No Flutter SDK required.
