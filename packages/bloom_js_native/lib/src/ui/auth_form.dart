import '../framework.dart';
import '../signals.dart';
import 'button.dart';
import 'cn.dart';
import 'input.dart';
import 'label.dart';

/// Pre-built authentication form card with email/password inputs, validation,
/// error banner, and optional social login slots.
BloomNode authForm({
  String title = 'Sign in',
  String? subtitle,
  String submitLabel = 'Continue',
  Signal<String>? email,
  Signal<String>? password,
  Signal<String?>? error,
  Signal<bool>? loading,
  void Function(String email, String password)? onSubmit,
  List<BloomNode> socialActions = const [],
  BloomNode? footer,
  String extraClassName = '',
}) {
  final emailSig = email ?? signal<String>('');
  final passwordSig = password ?? signal<String>('');
  final errorSig = error ?? signal<String?>(null);
  final loadingSig = loading ?? signal<bool>(false);

  return Div(
    className: cn([
      'w-full max-w-md rounded-[var(--radius-lg)] border border-[var(--border)] '
          'bg-[var(--card)] text-[var(--card-foreground)] p-6 shadow-[var(--shadow-card)] space-y-5',
      extraClassName,
    ]),
    children: [
      Div(
        className: 'space-y-1',
        children: [
          H2(className: 'text-xl font-bold', text: title),
          if (subtitle != null)
            P(
              className: 'text-sm text-[var(--text-muted)]',
              text: subtitle,
            ),
        ],
      ),
      Show(
        () => errorSig.value != null && errorSig.value!.isNotEmpty,
        child: Live(() => Div(
              attrs: const {'role': 'alert'},
              className:
                  'rounded-[var(--radius-md)] border border-[var(--destructive)]/40 '
                  'bg-[var(--destructive)]/10 px-3 py-2 text-xs text-[var(--destructive)]',
              text: errorSig.value ?? '',
            )),
      ),
      Form(
        className: 'space-y-4',
        onSubmit: (e) {
          e.preventDefault();
          onSubmit?.call(emailSig.value, passwordSig.value);
        },
        children: [
          Div(
            className: 'space-y-1.5',
            children: [
              label(text: 'Email', htmlFor: 'auth-email'),
              textInput(
                id: 'auth-email',
                type: 'email',
                placeholder: 'name@example.com',
                value: emailSig.value,
                onInput: (e) => emailSig.value = e.value ?? '',
              ),
            ],
          ),
          Div(
            className: 'space-y-1.5',
            children: [
              label(text: 'Password', htmlFor: 'auth-password'),
              textInput(
                id: 'auth-password',
                type: 'password',
                placeholder: '••••••••',
                value: passwordSig.value,
                onInput: (e) => passwordSig.value = e.value ?? '',
              ),
            ],
          ),
          Live(() => button(
                text: submitLabel,
                loading: loadingSig.value,
                extraClassName: 'w-full',
                attrs: const {'type': 'submit'},
              )),
        ],
      ),
      if (socialActions.isNotEmpty)
        Div(
          className: 'space-y-2 pt-2 border-t border-[var(--border)]',
          children: socialActions,
        ),
      if (footer != null) Div(className: 'pt-2', children: [footer]),
    ],
  );
}
