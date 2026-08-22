@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('eval')
external JSAny? _jsEval(String code);

void main() {
  group('BloomVirtualItem model', () {
    test('constructs with correct properties', () {
      const item = BloomVirtualItem(index: 5, start: 150.0, size: 30.0);
      expect(item.index, 5);
      expect(item.start, 150.0);
      expect(item.size, 30.0);
    });
  });

  group('BloomVirtualizer lifecycle and signal integration with mock JS core', () {
    setUp(() {
      _jsEval('''
        window.__bloomVirtualCore = {
          Virtualizer: function(options) {
            this.options = options;
            this._mounted = false;
            this.getVirtualItems = function() {
              return [
                { index: 0, start: 0, size: 50, key: '0' },
                { index: 1, start: 50, size: 50, key: '1' }
              ];
            };
            this.getTotalSize = function() {
              return 100;
            };
            this._didMount = function() {
              this._mounted = true;
              return function() {
                this._mounted = false;
              };
            };
            this._willUpdate = function() {};
            this.setOptions = function(opts) {
              this.options = opts;
            };
            this.scrollToIndex = function(idx, opts) {};
          },
          observeElementRect: function() {},
          observeElementOffset: function() {},
          elementScroll: function() {}
        };
      ''');
    });

    test('initializes signals, attaches, refreshes, and pulls virtual items', () {
      final scrollRef = Ref<web.Element>();
      final host = web.document.createElement('div');
      web.document.body?.appendChild(host);
      addTearDown(() => host.remove());

      scrollRef.attach(host);

      var itemCount = 10;
      final virtualizer = BloomVirtualizer(
        scrollElementRef: scrollRef,
        count: () => itemCount,
        estimateSize: (i) => 50.0,
        overscan: 3,
      );

      expect(virtualizer.items.value, isEmpty);
      expect(virtualizer.totalSize.value, 0.0);

      virtualizer.attach();

      expect(virtualizer.items.value.length, 2);
      expect(virtualizer.items.value[0].index, 0);
      expect(virtualizer.items.value[0].start, 0.0);
      expect(virtualizer.items.value[0].size, 50.0);
      expect(virtualizer.items.value[1].index, 1);
      expect(virtualizer.items.value[1].start, 50.0);
      expect(virtualizer.totalSize.value, 100.0);

      itemCount = 20;
      virtualizer.refresh();
      expect(virtualizer.items.value.length, 2);

      virtualizer.dispose();
    });
  });
}
