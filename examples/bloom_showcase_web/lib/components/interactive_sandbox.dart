import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:web/web.dart' as web;
import '../plugins/confetti.dart';
import '../state/showcase_store.dart';

class InteractiveSandboxComponent {
  final ShowcaseStore store;
  final activeSandboxTab = signal<int>(0);

  // Todo Sandbox State
  final todos = signal<List<({String id, String text, bool done})>>([
    (id: '1', text: 'Build fine-grained Web app in Dart', done: true),
    (id: '2', text: 'Vendor NPM packages with Bun', done: true),
    (id: '3', text: 'Deploy to Cloudflare edge in <1ms', done: false),
  ]);
  String _todoInputDraft = '';

  // Counter Sandbox State
  final counter = signal<int>(42);
  late final isEven = computed(() => counter.value.isEven);

  // Form Validator State
  final email = signal<String>('');
  final password = signal<String>('');
  late final isEmailValid = computed(() => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.value));
  late final isPasswordStrong = computed(() => password.value.length >= 8);

  InteractiveSandboxComponent(this.store);

  BloomNode build() {
    return Section(
      attrs: {'id': 'sandbox'},
      className: 'py-20 px-6 max-w-7xl mx-auto',
      children: [
        // Section Header
        Div(
          className: 'text-center max-w-3xl mx-auto mb-12',
          children: [
            Span(className: 'text-xs font-mono text-indigo-400 font-semibold uppercase tracking-wider', text: 'Interactive Component Lab'),
            H2(className: 'text-3xl sm:text-4xl font-bold text-white mt-2 mb-4', text: 'Test-Drive Bloom Reactivity Live'),
            P(className: 'text-zinc-400 text-base leading-relaxed', text: 'Every interaction below runs 100% fine-grained Bloom signals compiled from pure Dart. No virtual DOM diffing, no state loss.'),
          ],
        ),

        // Sandbox Shell
        Div(
          className: 'max-w-4xl mx-auto rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl',
          children: [
            // Tabs Bar
            Div(
              className: 'flex items-center gap-2 pb-6 border-b border-[#1E1E24] overflow-x-auto custom-scrollbar',
              children: [
                _sandboxTab(0, 'Keyed Reactive List'),
                _sandboxTab(1, 'Signal Counter'),
                _sandboxTab(2, 'Live Form Validation'),
                _sandboxTab(3, 'Confetti Particle Cannon'),
              ],
            ),

            // Tab Viewports
            Div(
              className: 'pt-6',
              children: [
                Live(() {
                  switch (activeSandboxTab.value) {
                    case 1:
                      return _counterView();
                    case 2:
                      return _formValidationView();
                    case 3:
                      return _confettiCannonView();
                    default:
                      return _todoListView();
                  }
                }),
              ],
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _sandboxTab(int index, String title) {
    return Live(() {
      final isSelected = activeSandboxTab.value == index;
      return Button(
        className: 'px-4 py-2 text-xs font-medium rounded-lg transition-all cursor-pointer whitespace-nowrap ${isSelected ? "bg-indigo-600 text-white shadow-md shadow-indigo-600/20" : "bg-[#14141A] hover:bg-[#1E1E24] text-zinc-400 hover:text-white border border-[#27272A]"}',
        onClick: (_) => activeSandboxTab.value = index,
        text: title,
      );
    });
  }

  // 1. Keyed Todo View (Persistent inputs without focus loss)
  BloomNode _todoListView() {
    return Div(
      className: 'space-y-4 max-w-xl mx-auto',
      children: [
        // Input bar
        Div(
          className: 'flex gap-3',
          children: [
            Input(
              placeholder: 'Add new task...',
              className: 'flex-1 bg-[#14141A] border border-[#27272A] rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500 transition-colors',
              onInput: (e) {
                _todoInputDraft = e.value ?? '';
              },
            ),
            Button(
              className: 'px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-semibold cursor-pointer transition-colors shadow-md active:scale-95',
              onClick: (_) {
                final txt = _todoInputDraft.trim();
                if (txt.isNotEmpty) {
                  todos.value = [
                    ...todos.value,
                    (id: DateTime.now().millisecondsSinceEpoch.toString(), text: txt, done: false),
                  ];
                  _todoInputDraft = '';

                  // Clear input field DOM value
                  final el = web.document.querySelector('#sandbox input') as web.HTMLInputElement?;
                  if (el != null) el.value = '';

                  Confetti.burst(x: 0.5, y: 0.5);
                }
              },
              text: 'Add Task',
            ),
          ],
        ),

        // List items
        Div(
          className: 'space-y-2 pt-2',
          children: [
            ForEach<({String id, String text, bool done})>(
              () => todos.value,
              (item) => Div(
                className: 'p-3.5 rounded-xl bg-[#14141A] border border-[#27272A] flex items-center justify-between transition-all hover:border-zinc-700',
                children: [
                  Div(
                    className: 'flex items-center gap-3',
                    children: [
                      Button(
                        className: 'w-5 h-5 rounded-md flex items-center justify-center border transition-colors cursor-pointer ${item.done ? "bg-indigo-600 border-indigo-500 text-white" : "border-zinc-700 hover:border-zinc-500"}',
                        onClick: (_) {
                          todos.value = todos.value.map((t) => t.id == item.id ? (id: t.id, text: t.text, done: !t.done) : t).toList();
                          if (!item.done) Confetti.burst(x: 0.5, y: 0.5);
                        },
                        children: [
                          if (item.done)
                            Raw('<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>'),
                        ],
                      ),
                      Span(className: 'text-sm ${item.done ? "line-through text-zinc-500" : "text-zinc-200"}', text: item.text),
                    ],
                  ),
                  Button(
                    className: 'text-xs text-zinc-500 hover:text-red-400 transition-colors p-1 cursor-pointer',
                    onClick: (_) => todos.value = todos.value.where((t) => t.id != item.id).toList(),
                    children: [
                      Raw('<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>'),
                    ],
                  ),
                ],
              ),
              key: (item) => item.id,
            ),
          ],
        ),
      ],
    );
  }

  // 2. Counter View
  BloomNode _counterView() {
    return Div(
      className: 'text-center py-6 max-w-sm mx-auto space-y-6',
      children: [
        Div(
          className: 'p-6 rounded-2xl bg-[#14141A] border border-[#27272A]',
          children: [
            Span(className: 'text-xs font-mono text-zinc-500 uppercase tracking-widest', text: 'Signal Value'),
            Live(() => H3(className: 'text-5xl font-extrabold font-mono text-white mt-2 mb-1', text: '${counter.value}')),
            Live(() => Span(className: 'text-xs font-mono px-2.5 py-0.5 rounded-full ${isEven.value ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20" : "bg-violet-500/10 text-violet-400 border border-violet-500/20"}', text: isEven.value ? 'Even Number' : 'Odd Number')),
          ],
        ),
        Div(
          className: 'flex justify-center gap-3',
          children: [
            Button(
              className: 'px-5 py-2.5 rounded-xl bg-[#1E1E24] hover:bg-[#27272A] text-white font-mono text-sm cursor-pointer border border-[#27272A] active:scale-95',
              onClick: (_) => counter.value--,
              text: '- Decrement',
            ),
            Button(
              className: 'px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-mono text-sm cursor-pointer shadow-md shadow-indigo-600/20 active:scale-95',
              onClick: (_) => counter.value++,
              text: '+ Increment',
            ),
          ],
        ),
      ],
    );
  }

  // 3. Form Validation View
  BloomNode _formValidationView() {
    return Div(
      className: 'max-w-md mx-auto space-y-4 py-2',
      children: [
        Div(
          className: 'space-y-1.5',
          children: [
            Span(className: 'text-xs font-medium text-zinc-300', text: 'Email Address'),
            Input(
              placeholder: 'alex@bloom.dev',
              className: 'w-full bg-[#14141A] border border-[#27272A] rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500',
              onInput: (e) => email.value = e.value ?? '',
            ),
            Live(() => email.value.isEmpty
                ? const Fragment.fromList([])
                : Span(
                    className: 'text-xs font-mono ${isEmailValid.value ? "text-emerald-400" : "text-amber-400"}',
                    text: isEmailValid.value ? '✓ Valid email syntax' : '⚠ Invalid email address',
                  )),
          ],
        ),
        Div(
          className: 'space-y-1.5',
          children: [
            Span(className: 'text-xs font-medium text-zinc-300', text: 'Password (min 8 chars)'),
            Input(
              type: 'password',
              placeholder: '••••••••',
              className: 'w-full bg-[#14141A] border border-[#27272A] rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500',
              onInput: (e) => password.value = e.value ?? '',
            ),
            Live(() => password.value.isEmpty
                ? const Fragment.fromList([])
                : Span(
                    className: 'text-xs font-mono ${isPasswordStrong.value ? "text-emerald-400" : "text-amber-400"}',
                    text: isPasswordStrong.value ? '✓ Strong password length' : '⚠ Requires at least 8 characters',
                  )),
          ],
        ),
        Button(
          className: 'w-full py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-indigo-600/25 mt-4 active:scale-95',
          onClick: (_) {
            if (isEmailValid.value && isPasswordStrong.value) {
              store.showToast('Validation Success! Account Ready.');
              Confetti.burst(x: 0.5, y: 0.5);
            } else {
              store.showToast('Please fulfill validation requirements.');
            }
          },
          text: 'Validate Form State',
        ),
      ],
    );
  }

  // 4. Confetti Cannon View
  BloomNode _confettiCannonView() {
    return Div(
      className: 'text-center py-8 space-y-6 max-w-md mx-auto',
      children: [
        P(className: 'text-zinc-400 text-sm leading-relaxed', text: 'Trigger multi-stage ESM particles powered by canvas-confetti native JS bindings.'),
        Div(
          className: 'flex justify-center gap-4 flex-wrap',
          children: [
            Button(
              className: 'px-5 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-indigo-600/30 active:scale-95',
              onClick: (_) => Confetti.burst(x: 0.5, y: 0.5),
              text: 'Center Explosion',
            ),
            Button(
              className: 'px-5 py-3 rounded-xl bg-violet-600 hover:bg-violet-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-violet-600/30 active:scale-95',
              onClick: (_) {
                Confetti.burst(x: 0.2, y: 0.6);
                Confetti.burst(x: 0.8, y: 0.6);
              },
              text: 'Dual Cannons',
            ),
          ],
        ),
      ],
    );
  }
}
