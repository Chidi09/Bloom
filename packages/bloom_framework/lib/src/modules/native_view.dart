// lib/src/modules/native_view.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:bloom_ui/bloom_ui.dart' as ui;

/// A cross-platform bridge widget for hosting hardware-accelerated native views
/// (e.g. Camera Preview, MapKit/Google Maps, AR views, WebViews) declared in Bloom Modules.
///
/// On Android, hosts an `AndroidViewSurface` via `PlatformViewsService`.
/// On iOS, hosts an `UiKitView`.
/// On Web and in Flutter test environments, renders a graceful [fallback] widget.
///
/// Example:
/// ```dart
/// BloomNativeView(
///   viewType: 'BloomCameraView',
///   props: {'lensFacing': 'back', 'flashMode': 'auto'},
///   onEvent: (name, payload) {
///     print('Event from native view: $name -> $payload');
///   },
///   fallback: Text('Camera not supported on this platform'),
/// )
/// ```
class BloomNativeView extends StatefulWidget {
  /// The registered view identifier matching the native ViewFactory name on the host platform.
  final String viewType;

  /// Declarative properties passed to the native view during creation and updates.
  final Map<String, dynamic> props;

  /// Event callback invoked when the native view emits a platform event across the method channel.
  final void Function(String eventName, dynamic payload)? onEvent;

  /// Custom fallback widget rendered on unsupported platforms (such as Web) or during widget testing.
  final Widget? fallback;

  /// Custom layout gesture recognizers forwarded to the native platform view.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// Creates a [BloomNativeView] widget.
  const BloomNativeView({
    super.key,
    required this.viewType,
    this.props = const {},
    this.onEvent,
    this.fallback,
    this.gestureRecognizers,
  });

  @override
  State<BloomNativeView> createState() => _BloomNativeViewState();
}

class _BloomNativeViewState extends State<BloomNativeView> {
  MethodChannel? _channel;
  Map<String, dynamic>? _pendingProps;

  @override
  void didUpdateWidget(covariant BloomNativeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.props, widget.props)) {
      _updateNativeProps();
    }
  }

  void _updateNativeProps() {
    if (_channel != null) {
      _channel?.invokeMethod('updateProps', widget.props);
      _pendingProps = null;
    } else {
      _pendingProps = Map<String, dynamic>.from(widget.props);
    }
  }

  void _onPlatformViewCreated(int id) {
    final channelName = 'dev.bloom.views/${widget.viewType}_$id';
    _channel = MethodChannel(channelName);
    _channel?.setMethodCallHandler((call) async {
      widget.onEvent?.call(call.method, call.arguments);
    });

    if (_pendingProps != null) {
      _channel?.invokeMethod('updateProps', _pendingProps);
      _pendingProps = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // In Flutter test harness or Web, render a structured mock container
    if (kIsWeb) {
      return widget.fallback ?? _buildFallback('Web Platform View: ${widget.viewType}');
    }

    try {
      if (Platform.isAndroid) {
        return PlatformViewLink(
          viewType: widget.viewType,
          surfaceFactory: (context, controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: widget.gestureRecognizers ?? const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (params) {
            return PlatformViewsService.initSurfaceAndroidView(
              id: params.id,
              viewType: widget.viewType,
              layoutDirection: TextDirection.ltr,
              creationParams: widget.props,
              creationParamsCodec: const StandardMessageCodec(),
              onFocus: () {
                params.onFocusChanged(true);
              },
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..addOnPlatformViewCreatedListener(_onPlatformViewCreated)
              ..create();
          },
        );
      } else if (Platform.isIOS) {
        return UiKitView(
          viewType: widget.viewType,
          creationParams: widget.props,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
        );
      }
    } catch (_) {
      // Catch platform inspection exceptions in tests
    }

    return widget.fallback ?? _buildFallback('Native Platform View: ${widget.viewType}');
  }

  Widget _buildFallback(String label) {
    return Container(
      color: const Color(0xDD000000),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ui.BloomIcon(ui.BloomIcons.layers, color: Color(0xFF64FFDA), size: 36),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          if (widget.props.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Props: ${widget.props}',
              style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
