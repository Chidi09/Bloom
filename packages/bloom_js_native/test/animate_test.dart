import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomKeyframe', () {
    test('toCssPercent for offset 0.0', () {
      const kf = BloomKeyframe(offset: 0.0, styles: {'opacity': '0'});
      expect(kf.toCssPercent(), '0%');
    });

    test('toCssPercent for offset 0.5', () {
      const kf = BloomKeyframe(offset: 0.5, styles: {'opacity': '0.5'});
      expect(kf.toCssPercent(), '50%');
    });

    test('toCssPercent for offset 1.0', () {
      const kf = BloomKeyframe(offset: 1.0, styles: {'opacity': '1'});
      expect(kf.toCssPercent(), '100%');
    });

    test('toCssBlock produces valid CSS', () {
      const kf = BloomKeyframe(
          offset: 0.0, styles: {'opacity': '0', 'transform': 'scale(0.8)'});
      final css = kf.toCssBlock();
      expect(css, startsWith('0%{'));
      expect(css, contains('opacity:0'));
    });
  });

  group('BloomAnimation', () {
    test('defaults are sensible', () {
      const anim = BloomAnimation(
        name: 'test',
        keyframes: [
          BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
          BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
        ],
      );
      expect(anim.duration, const Duration(milliseconds: 300));
      expect(anim.delay, Duration.zero);
      expect(anim.iterations, 1);
      expect(anim.easing, 'ease');
      expect(anim.fillMode, 'both');
      expect(anim.direction, 'normal');
    });

    test('toKeyframesCSS generates @keyframes block', () {
      const anim = BloomAnimation(
        name: 'fade',
        keyframes: [
          BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
          BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
        ],
      );
      final css = anim.toKeyframesCSS();
      expect(css, contains('@keyframes fade'));
      expect(css, contains('0%'));
      expect(css, contains('100%'));
      expect(css, contains('opacity:0'));
      expect(css, contains('opacity:1'));
    });

    test('toInlineStyle encodes all animation properties', () {
      const anim = BloomAnimation(
        name: 'slide',
        keyframes: [],
        duration: Duration(milliseconds: 500),
        delay: Duration(milliseconds: 100),
        iterations: 3,
        easing: 'linear',
        fillMode: 'forwards',
        direction: 'alternate',
      );
      final style = anim.toInlineStyle();
      expect(style, contains('slide'));
      expect(style, contains('500ms'));
      expect(style, contains('100ms'));
      expect(style, contains('3'));
      expect(style, contains('linear'));
      expect(style, contains('forwards'));
      expect(style, contains('alternate'));
    });

    test('infinite iterations uses "infinite" string', () {
      const anim = BloomAnimation(
          name: 'pulse', keyframes: [], iterations: -1);
      expect(anim.toInlineStyle(), contains('infinite'));
    });
  });

  group('AnimatedNode SSR', () {
    test('renderToHtml includes @keyframes and animation style', () {
      final node = Animated(
        animation: const BloomAnimation(
          name: 'fade-in',
          keyframes: [
            BloomKeyframe(offset: 0.0, styles: {'opacity': '0'}),
            BloomKeyframe(offset: 1.0, styles: {'opacity': '1'}),
          ],
        ),
        child: Div(children: [Text('hello')]),
      );
      final html = renderToHtml(node);
      expect(html, contains('@keyframes fade-in'));
      expect(html, contains('animation:'));
      expect(html, contains('hello'));
    });

    test('identical animation names deduplicated across siblings', () {
      const anim = BloomAnimation(
        name: 'slide',
        keyframes: [
          BloomKeyframe(offset: 0.0, styles: {'transform': 'translateX(-100%)'}),
          BloomKeyframe(offset: 1.0, styles: {'transform': 'translateX(0)'}),
        ],
      );
      final tree = Div(children: [
        Animated(animation: anim, child: Span(text: 'a')),
        Animated(animation: anim, child: Span(text: 'b')),
      ]);
      final html = renderToHtml(tree);
      expect('@keyframes slide'.allMatches(html).length, 1);
    });
  });

  group('BloomAnimationPresets', () {
    test('fadeIn name is bloom-fade-in', () {
      expect(BloomAnimationPresets.fadeIn.name, 'bloom-fade-in');
    });

    test('fadeIn has exactly 2 keyframes', () {
      expect(BloomAnimationPresets.fadeIn.keyframes.length, 2);
    });

    test('fadeOut goes from opacity 1 to 0', () {
      expect(BloomAnimationPresets.fadeOut.keyframes.first.styles['opacity'], '1');
      expect(BloomAnimationPresets.fadeOut.keyframes.last.styles['opacity'], '0');
    });

    test('slideInLeft has transform in keyframes', () {
      expect(BloomAnimationPresets.slideInLeft.keyframes.first.styles,
          containsPair('transform', anything));
    });

    test('scaleIn has scale in keyframes', () {
      expect(BloomAnimationPresets.scaleIn.keyframes.first.styles['transform'],
          contains('scale'));
    });

    test('pulse has 3 keyframes', () {
      expect(BloomAnimationPresets.pulse.keyframes.length, 3);
    });

    test('pulse uses infinite iterations', () {
      expect(BloomAnimationPresets.pulse.iterations, -1);
    });
  });
}
