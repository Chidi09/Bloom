import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import '../state/store.dart';

class AuthComponent {
  final EcommerceStore store;
  final BloomRouterController router;

  AuthComponent(this.store, this.router);

  final _mode = signal<String>('login'); // 'login' | 'signup'
  final _name = signal<String>('');
  final _email = signal<String>('');
  final _password = signal<String>('');

  BloomNode build() {
    return Main(
      className: 'max-w-md mx-auto px-6 py-10',
      children: [
        Live(() {
          if (store.isLoggedIn) {
            return Div(
              children: [
                P(className: 'text-white', text: 'You are already logged in.'),
                A(
                  text: 'Continue shopping',
                  href: '/',
                  className: 'inline-block mt-4 px-4 py-2 rounded-lg bg-indigo-600 text-white text-sm',
                  onClick: (e) {
                    e.preventDefault();
                    router.navigate('/');
                  },
                ),
              ],
            );
          }
          return _buildForm();
        }),
      ],
    );
  }

  BloomNode _buildForm() {
    final isSignup = _mode.value == 'signup';

    return Form(
      className: 'flex flex-col gap-4',
      onSubmit: (e) {
        e.preventDefault();
        if (isSignup) {
          store.signup(_name.value, _email.value, _password.value);
        } else {
          store.login(_email.value, _password.value);
        }
      },
      children: [
        H1(
          className: 'text-2xl font-bold text-white mb-2',
          text: isSignup ? 'Create an account' : 'Log in',
        ),
        if (isSignup)
          Div(
            children: [
              Label(text: 'Name', className: 'block text-sm text-zinc-400 mb-1'),
              Input(
                className: 'w-full px-3 py-2 rounded-lg bg-zinc-900 border border-zinc-700 text-white',
                value: _name.value,
                onInput: (e) => _name.value = e.value ?? '',
              ),
            ],
          ),
        Div(
          children: [
            Label(text: 'Email', className: 'block text-sm text-zinc-400 mb-1'),
            Input(
              type: 'email',
              className: 'w-full px-3 py-2 rounded-lg bg-zinc-900 border border-zinc-700 text-white',
              value: _email.value,
              onInput: (e) => _email.value = e.value ?? '',
            ),
          ],
        ),
        Div(
          children: [
            Label(text: 'Password', className: 'block text-sm text-zinc-400 mb-1'),
            Input(
              type: 'password',
              className: 'w-full px-3 py-2 rounded-lg bg-zinc-900 border border-zinc-700 text-white',
              value: _password.value,
              onInput: (e) => _password.value = e.value ?? '',
            ),
          ],
        ),
        Live(() {
          final err = store.authError.value;
          if (err == null) return const Fragment(children: []);
          return P(className: 'text-red-400 text-sm', text: err);
        }),
        Button(
          text: store.authBusy.value
              ? 'Please wait...'
              : (isSignup ? 'Sign up' : 'Log in'),
          className: 'px-4 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-medium',
        ),
        Button.raw(
          text: isSignup ? 'Have an account? Log in' : "Don't have an account? Sign up",
          className: 'text-sm text-zinc-400 hover:text-white text-left',
          attrs: const {'type': 'button'},
          on: {
            'click': (BloomEvent e) {
              e.preventDefault();
              _mode.value = isSignup ? 'login' : 'signup';
            },
          },
        ),
      ],
    );
  }
}
