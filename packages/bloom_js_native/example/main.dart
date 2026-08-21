import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

class TodoItem {
  final String id;
  final String title;
  final bool completed;

  const TodoItem({
    required this.id,
    required this.title,
    this.completed = false,
  });

  TodoItem copyWith({String? title, bool? completed}) => TodoItem(
        id: id,
        title: title ?? this.title,
        completed: completed ?? this.completed,
      );
}

enum TodoFilter { all, active, completed }

/// Counter + Todo demo for Bloom JS Native.
/// Compile with: dart compile js -O4 -o main.js main.dart
void main() {
  // ── State ──────────────────────────────────────────────────────────
  final count = signal(0);
  final todos = signal<List<TodoItem>>([
    const TodoItem(
        id: '1', title: 'Architect pure-Dart descriptor tree', completed: true),
    const TodoItem(
        id: '2',
        title: 'Mount fine-grained DOM with signals',
        completed: true),
    const TodoItem(
        id: '3', title: 'Ship Bloom JS Native M1-M3', completed: false),
  ]);
  final filter = signal(TodoFilter.all);
  final inputValue = signal('');

  // ── Derived ────────────────────────────────────────────────────────
  final doubled = computed(() => count.value * 2);
  final filteredTodos = computed(() {
    switch (filter.value) {
      case TodoFilter.all:
        return todos.value;
      case TodoFilter.active:
        return todos.value.where((t) => !t.completed).toList();
      case TodoFilter.completed:
        return todos.value.where((t) => t.completed).toList();
    }
  });
  final activeCount =
      computed(() => todos.value.where((t) => !t.completed).length);

  // ── Actions ────────────────────────────────────────────────────────
  void addTodo(BloomEvent e) {
    e.preventDefault();
    final v = inputValue.value.trim();
    if (v.isEmpty) return;
    todos.value = [
      ...todos.value,
      TodoItem(id: DateTime.now().millisecondsSinceEpoch.toString(), title: v),
    ];
    inputValue.value = '';
  }

  void toggleTodo(String id) {
    todos.value = [
      for (final t in todos.value)
        if (t.id == id) t.copyWith(completed: !t.completed) else t
    ];
  }

  void removeTodo(String id) {
    todos.value = todos.value.where((t) => t.id != id).toList();
  }

  // ── View ───────────────────────────────────────────────────────────
  final app = Div(
    className:
        'min-h-screen bg-[#09090B] text-zinc-100 font-sans antialiased selection:bg-indigo-500 selection:text-white',
    children: [
      Div(
        className: 'max-w-2xl mx-auto px-6 py-12 space-y-8',
        children: [
          // Header
          Header(
            className: 'border-b border-[#1E1E24] pb-6 space-y-2',
            children: [
              Div(
                className: 'flex items-center space-x-3',
                children: [
                  Div(
                    className:
                        'w-7 h-7 rounded-md bg-indigo-600 flex items-center justify-center font-bold text-white text-sm shadow-md shadow-indigo-500/20',
                    children: const [Text('B')],
                  ),
                  H1(
                    text: 'Bloom JS Native',
                    className:
                        'text-2xl font-bold tracking-tight text-zinc-100',
                  ),
                  Span(
                    text: 'v0.1.0',
                    className:
                        'px-2 py-0.5 text-xs font-mono bg-[#14141A] border border-[#27272A] rounded text-zinc-400',
                  ),
                ],
              ),
              P(
                text:
                    'Dart-owned reactivity with native DOM rendering and zero Flutter overhead.',
                className: 'text-sm text-zinc-400',
              ),
            ],
          ),

          // Metric / Counter Card
          Section(
            className:
                'p-5 bg-[#14141A] border border-[#27272A] rounded-xl space-y-4 shadow-xl',
            children: [
              Div(
                className: 'flex items-center justify-between',
                children: [
                  H2(
                      text: 'Reactive State Engine',
                      className:
                          'text-sm font-semibold text-zinc-300 uppercase tracking-wider'),
                  Span(
                      text: 'signals ^5.5.0',
                      className: 'text-xs text-indigo-400 font-mono'),
                ],
              ),
              Div(
                className: 'grid grid-cols-2 gap-4 py-2',
                children: [
                  Div(
                    className:
                        'p-3 bg-[#09090B] border border-[#1E1E24] rounded-lg',
                    children: [
                      P(
                          text: 'Primary Signal',
                          className: 'text-xs text-zinc-500'),
                      Live(() => P(
                          text: '${count.value}',
                          className:
                              'text-2xl font-bold text-zinc-100 font-mono')),
                    ],
                  ),
                  Div(
                    className:
                        'p-3 bg-[#09090B] border border-[#1E1E24] rounded-lg',
                    children: [
                      P(
                          text: 'Computed 2x',
                          className: 'text-xs text-zinc-500'),
                      Live(() => P(
                          text: '${doubled.value}',
                          className:
                              'text-2xl font-bold text-indigo-400 font-mono')),
                    ],
                  ),
                ],
              ),
              Div(
                className: 'flex items-center space-x-2',
                children: [
                  Button(
                    text: 'Decrement (-1)',
                    className:
                        'px-3 py-1.5 text-xs font-medium bg-[#1E1E24] hover:bg-[#27272A] text-zinc-300 border border-[#27272A] rounded-lg transition-colors cursor-pointer',
                    onClick: (_) => count.value--,
                  ),
                  Button(
                    text: 'Increment (+1)',
                    className:
                        'px-3 py-1.5 text-xs font-medium bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg shadow-sm shadow-indigo-600/30 transition-colors cursor-pointer',
                    onClick: (_) => count.value++,
                  ),
                  Button(
                    text: 'Reset',
                    className:
                        'px-3 py-1.5 text-xs font-medium text-zinc-400 hover:text-zinc-200 transition-colors cursor-pointer',
                    onClick: (_) => count.value = 0,
                  ),
                ],
              ),
              Show(
                () => count.value >= 10,
                child: Div(
                  className:
                      'px-3 py-2 bg-indigo-950/40 border border-indigo-800/50 rounded-lg text-xs text-indigo-300',
                  children: const [Text('Double digit milestone reached.')],
                ),
                fallback: Div(
                  className:
                      'px-3 py-2 bg-[#09090B]/60 border border-[#1E1E24] rounded-lg text-xs text-zinc-500',
                  children: const [
                    Text('Increment count to 10 to test Show condition.')
                  ],
                ),
              ),
            ],
          ),

          // Todo Task Section
          Section(
            className:
                'p-5 bg-[#14141A] border border-[#27272A] rounded-xl space-y-4 shadow-xl',
            children: [
              Div(
                className: 'flex items-center justify-between',
                children: [
                  H2(
                      text: 'Tasks & Fine-Grained DOM',
                      className:
                          'text-sm font-semibold text-zinc-300 uppercase tracking-wider'),
                  Live(() => Span(
                      text: '${activeCount.value} pending',
                      className: 'text-xs text-zinc-400 font-mono')),
                ],
              ),
              Form(
                onSubmit: addTodo,
                className: 'flex gap-2',
                children: [
                  Input(
                    placeholder: 'Create new task descriptor...',
                    className:
                        'flex-1 px-3.5 py-2 text-sm bg-[#09090B] border border-[#27272A] rounded-lg text-zinc-100 placeholder:text-zinc-600 focus:outline-none focus:border-indigo-500',
                    attrs: {'value': inputValue.value},
                    onInput: (e) => inputValue.value = e.value ?? '',
                  ),
                  Button(
                    text: 'Add Task',
                    className:
                        'px-4 py-2 text-sm font-medium bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg transition-colors cursor-pointer',
                    attrs: const {'type': 'submit'},
                  ),
                ],
              ),
              // Filters
              Div(
                className: 'flex space-x-1 border-b border-[#1E1E24] pb-2',
                children: [
                  for (final f in TodoFilter.values)
                    Live(() {
                      final isActive = filter.value == f;
                      return Button(
                        text: f.name.toUpperCase(),
                        className:
                            'px-2.5 py-1 text-xs font-mono rounded cursor-pointer ${isActive ? 'bg-indigo-600/20 text-indigo-400 border border-indigo-500/30' : 'text-zinc-500 hover:text-zinc-300'}',
                        onClick: (_) => filter.value = f,
                      );
                    }),
                ],
              ),
              // List
              Ul(
                className: 'space-y-2 pt-1',
                children: [
                  ForEach<TodoItem>(
                    () => filteredTodos.value,
                    (TodoItem t) => Li(
                      className:
                          'flex items-center justify-between p-3 bg-[#09090B] border border-[#1E1E24] hover:border-[#27272A] rounded-lg transition-colors',
                      children: [
                        Div(
                          className:
                              'flex items-center space-x-3 cursor-pointer',
                          onClick: (_) => toggleTodo(t.id),
                          children: [
                            Span(
                              text: t.title,
                              className:
                                  'text-sm ${t.completed ? 'line-through text-zinc-500' : 'text-zinc-200'}',
                            ),
                          ],
                        ),
                        Button(
                          text: 'Delete',
                          className:
                              'text-xs text-zinc-500 hover:text-red-400 cursor-pointer px-2 py-1',
                          onClick: (_) => removeTodo(t.id),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Footer
          Footer(
            className:
                'pt-4 border-t border-[#1E1E24] text-center text-xs text-zinc-600',
            children: const [
              Text(
                  'Bloom Framework — Pure Dart Descriptors + Direct Browser DOM'),
            ],
          ),
        ],
      ),
    ],
  );

  mount(app, '#app');
}
