# 04 — Interactivity, Events & Forms

Bloom JS Native provides a platform-agnostic, strongly-typed event system that allows interactive forms and event listeners to be written, executed in the browser, and unit-tested on the Dart VM without a browser environment.

---

## 1. The `BloomEvent` Abstraction

Event listeners receive a `BloomEvent` instance containing normalized event data:

```dart
Button(
  text: 'Submit Order',
  onClick: (BloomEvent e) {
    e.preventDefault();
    e.stopPropagation();
    print('Button clicked: ${e.type}');
  },
)
```

### Key Properties on `BloomEvent`
- `e.type`: The DOM event type name (e.g. `'click'`, `'input'`, `'change'`, `'submit'`, `'keydown'`).
- `e.value`: The string value of the input/textarea/select target (`String?`).
- `e.checked`: The boolean checked state of checkboxes or radio buttons (`bool?`).
- `e.preventDefault()`: Prevents the browser's default action.
- `e.stopPropagation()`: Stops event propagation up the DOM tree.
- `e.rawTarget`: Reference to the underlying browser DOM element (browser only).

---

## 2. Managing Form State & Inputs

When building interactive forms, **isolate input state from top-level `Live()` scopes** to preserve keyboard focus and cursor position during rapid typing:

```dart
class LoginForm {
  final email = signal('');
  final password = signal('');
  final isSubmitting = signal(false);

  late final isValid = computed(() =>
    email.value.contains('@') && password.value.length >= 8
  );

  BloomNode build() {
    return Form(
      className: 'max-w-md mx-auto p-6 rounded-2xl bg-[#14141A] border border-[#1E1E24] space-y-4',
      onSubmit: (e) {
        e.preventDefault();
        if (isValid.value) {
          _handleSubmit();
        }
      },
      children: [
        H2(className: 'text-2xl font-bold text-white', text: 'Sign In'),

        // Email Field
        Div(
          className: 'space-y-1',
          children: [
            Label(className: 'text-xs text-zinc-400', text: 'Email'),
            Input(
              type: 'email',
              placeholder: 'name@company.com',
              className: 'w-full px-3.5 py-2.5 rounded-lg bg-[#09090B] border border-[#27272A] text-white focus:outline-none focus:border-indigo-500',
              onInput: (e) => email.value = e.value ?? '',
            ),
          ],
        ),

        // Password Field
        Div(
          className: 'space-y-1',
          children: [
            Label(className: 'text-xs text-zinc-400', text: 'Password'),
            Input(
              type: 'password',
              placeholder: '••••••••',
              className: 'w-full px-3.5 py-2.5 rounded-lg bg-[#09090B] border border-[#27272A] text-white focus:outline-none focus:border-indigo-500',
              onInput: (e) => password.value = e.value ?? '',
            ),
          ],
        ),

        // Live Submit Button State
        Live(() => Button(
          className: 'w-full py-3 rounded-lg font-semibold text-xs transition-all ${isValid.value ? "bg-indigo-600 hover:bg-indigo-500 text-white cursor-pointer" : "bg-zinc-800 text-zinc-500 cursor-not-allowed"}',
          text: isSubmitting.value ? 'Authenticating...' : 'Sign In',
        )),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    isSubmitting.value = true;
    // Perform authentication...
    await Future.delayed(const Duration(seconds: 1));
    isSubmitting.value = false;
  }
}
```

---

## 3. Keyboard Shortcuts & Global Events

You can attach keyboard and window events using `package:web` or component event handlers:

```dart
Input(
  placeholder: 'Press Enter to search...',
  onKeyDown: (e) {
    // Check key from raw DOM event
    final domEvent = e.rawTarget;
    // Handle Enter submission...
  },
)
```

---

## 4. Testing Events on the Dart VM (Zero Browser Overhead)

Because `BloomEvent` is VM-compatible, your interactive components and store handlers can be tested in standard `dart test` without spinning up headless Chrome:

```dart
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  test('Form updates email on fake input event', () {
    final form = LoginForm();
    
    // Simulate typing
    final fakeEvent = BloomEvent.fakeInput('alex@bloom.dev');
    form.email.value = fakeEvent.value!;

    expect(form.email.value, equals('alex@bloom.dev'));
    expect(form.isValid.value, isFalse); // Password still empty
  });
}
```
