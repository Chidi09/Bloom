# 30. Deep Links, App Links & Universal Links

Bloom provides deep link routing that handles custom schemes (`bloom://`), Android App Links, and iOS Universal Links, with cold-start route buffering to prevent missed launches.

---

## 📜 Configuring Deep Links in `bloom.yaml`

```yaml
deep_links:
  enabled: true
  schemes:
    - bloomshop
    - bloom
  domains:
    - host: shop.bloom.dev
      sha256_cert_fingerprints:
        - "14:6D:E9:7F:0E:52:D7:1E:27:52:83:B6:B7:A0:64:13:E4:E8:1B:6F"
      app_store_team_id: "A1B2C3D4E5"
  routes:
    /products/:id: /product-detail
    /orders/:id: /order-status
```

---

## ⚡ Runtime Listener & Cold-Start Buffering

When an app is launched from a cold start (closed state) via a deep link, the initial intent arrives before Flutter's router is fully initialized.

`BloomDeepLinks` automatically buffers pending intents in an internal queue:

```dart
// 1. Initialized automatically during Bloom.boot()
await BloomDeepLinks.initialize(
  routeMappings: {
    '/products/:id': '/product-detail',
  },
);

// 2. Cold-start URLs are drained once the router is ready
BloomDeepLinks.drainPending((uri) {
  logger.info('Draining cold-start deep link: $uri');
  BloomRouter.go(uri.path);
});
```

---

## 📡 Live Intent Subscription

Listen to incoming deep link events while the app is already running in the background:

```dart
final sub = BloomDeepLinks.onLinkReceived.listen((uri) {
  logger.info('Deep link received in foreground: $uri');
  BloomRouter.go(uri.path);
});

// Cancel when no longer needed
sub.cancel();
```
