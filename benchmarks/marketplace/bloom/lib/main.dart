import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'components/layout.dart';

void main() {
  final app = appShell(Div(children: [
    H1(className: 'text-h1', text: 'Marketplace'),
    P(text: 'Client bundle — content is server-rendered. This shell hydrates interactivity.'),
  ]));
  mount(app, '#app');
}
