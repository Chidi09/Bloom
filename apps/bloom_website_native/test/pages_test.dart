import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_website_native/pages/blocks_page.dart';
import 'package:bloom_website_native/pages/bloom_page.dart';
import 'package:bloom_website_native/pages/build_page.dart';
import 'package:bloom_website_native/pages/home_page.dart';
import 'package:bloom_website_native/pages/server_page.dart';
import 'package:bloom_website_native/pages/ship_page.dart';
import 'package:test/test.dart';

void main() {
  test('homePage renders hero, chapters, orchestration, and CLI explorer', () {
    final html = renderToHtml(homePage());
    expect(html, contains('heroTypewriter'));
    expect(
      html,
      contains('The opinionated application platform for Dart &amp; Flutter'),
    );
    expect(html, contains('Executive Strategy'));
    expect(html, contains('dart pub global activate bloom_cli'));
  });

  test('bloomPage renders UI Studio picker and mobile components', () {
    final html = renderToHtml(bloomPage());
    expect(html, contains('Bloom UI Studio'));
    expect(html, contains('shadcn/ui for Flutter Mobile'));
    expect(html, contains('Standardize → Wrap → Generate → Orchestrate'));
    expect(html, contains('Production-Ready Mobile Architecture'));
  });

  test('buildPage renders signals simulator, boot DI, query, and routing', () {
    final html = renderToHtml(buildPage());
    expect(html, contains('File-based Routing &amp; Signals for Flutter'));
    expect(html, contains('Thin Boot Sequence &amp; Dependency Injection'));
    expect(html, contains('Fine-Grained Reactivity with Signals'));
    expect(html, contains('Declarative Data Fetching with Bloom Query'));
    expect(html, contains('Zero-Boilerplate Routing Engine'));
  });

  test('shipPage renders full OTA deployment pipeline and 15 glass panels', () {
    final html = renderToHtml(shipPage());
    expect(html, contains('Ship instantly'));
    expect(html, contains('Shorebird-Powered OTA'));
    expect(html, contains('Declarative Release Management'));
    expect(html, contains('Wireless Development &amp; Instant QR Installs'));
    expect(html, contains('Programmatic Update API'));
    expect(html, contains('Enterprise-Grade OTA Architecture'));
    expect(html, contains('One Dashboard, The Whole Release Lifecycle'));
  });

  test(
    'serverPage renders pure Dart backend platform, benchmarks, and FAQ',
    () {
      final html = renderToHtml(serverPage());
      expect(html, contains('Pure Dart Backend'));
      expect(html, contains('Django Power. Rust-Grade Concurrency'));
      expect(html, contains('One Language. One Workspace'));
      expect(html, contains('Hardware Performance Breakdown'));
      expect(html, contains('The 15-Package Server Ecosystem'));
      expect(
        html,
        contains('Frequently Asked Questions About Pure Dart Server'),
      );
    },
  );

  test(
    'blocksPage renders application blocks with copy buttons and code view',
    () {
      final html = renderToHtml(blocksPage());
      expect(html, contains('Application Blocks'));
      expect(html, contains('Production-Ready Screens'));
      expect(html, contains('Analytics &amp; Revenue Dashboard'));
      expect(html, contains('Clean Authentication Card'));
      expect(html, contains('AI Conversational Assistant'));
      expect(html, contains('App Settings &amp; Preferences'));
      expect(html, contains('Copy Flutter Code'));
    },
  );
}
