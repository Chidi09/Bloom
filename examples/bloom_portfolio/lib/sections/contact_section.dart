/// Validated contact form section with inline errors, EmailJS dispatch, and celebratory confetti.
library;

// signals is NOT imported directly: it is not a declared dependency of this
// example, so importing it would only resolve by accident through
// bloom_js_native. The reactive primitives (signal/computed/effect) are
// re-exported from bloom_js_native, which is the supported way to reach them.
import 'package:bloom_js_native/bloom_js_native.dart';
import '../config.dart';
import '../plugins/confetti.dart';
import '../plugins/emailjs.dart';
import '../plugins/lucide_icons.dart';

/// Contact section component.
class ContactSectionComponent {
  final BloomFormField _nameField = BloomFormField(
    validators: [
      required('Please enter your full name.'),
      minLength(2, 'Name must be at least 2 characters.'),
    ],
  );

  final BloomFormField _emailField = BloomFormField(
    validators: [
      required('Please enter your email address.'),
      email('Please enter a valid email address (e.g. name@domain.com).'),
    ],
  );

  final BloomFormField _messageField = BloomFormField(
    validators: [
      required('Please write a brief message or project outline.'),
      minLength(10, 'Message must be at least 10 characters.'),
    ],
  );

  late final BloomForm _form = BloomForm({
    'name': _nameField,
    'email': _emailField,
    'message': _messageField,
  });

  final Signal<String?> _statusMessage = signal(null);
  final Signal<bool> _isSuccess = signal(false);
  final Signal<bool> _copiedEmail = signal(false);

  BloomNode build() {
    return Section(
      attrs: {
        'id': 'contact',
        ...aria(
          role: AriaRole.region,
          label: 'Contact and Project Inquiries',
        ),
      },
      className: 'py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-zinc-900',
      children: [
        // Section Header
        Div(
          className: 'mb-16',
          children: [
            Span(
              className:
                  'font-mono text-xs text-indigo-400 font-semibold tracking-widest uppercase mb-2 block',
              text: '04. Initiation & Inquiries',
            ),
            H2(
              className: 'text-3xl sm:text-4xl font-bold tracking-tight text-zinc-50 mb-4',
              text: 'Let’s Build Something Exceptional',
            ),
            P(
              className: 'text-zinc-400 text-sm sm:text-base max-w-2xl',
              text:
                  'Have an ambitious systems project, architecture review, or consulting opportunity? Drop a note below.',
            ),
          ],
        ),

        // 2-Column Grid: Contact Information & Info Sidebar + Form
        Div(
          className: 'grid grid-cols-1 lg:grid-cols-12 gap-12 items-start',
          children: [
            // Left Column: Direct Inquiries & Response Expectations (5 cols)
            Div(
              className: 'lg:col-span-5 flex flex-col gap-6',
              children: [
                Div(
                  className: 'p-6 rounded-2xl bg-zinc-900/40 border border-zinc-800/80 shadow-lg',
                  children: [
                    H3(
                      className: 'text-lg font-semibold text-zinc-100 mb-2',
                      text: 'Direct Inquiries',
                    ),
                    P(
                      className: 'text-zinc-400 text-sm leading-relaxed mb-6',
                      text:
                          'I am currently open to consulting engagements, architectural advisory roles, and core engineering positions with innovative teams.',
                    ),

                    // Direct Email Copy Row
                    Div(
                      className:
                          'p-3.5 rounded-xl bg-zinc-950/80 border border-zinc-800 flex items-center justify-between gap-3 mb-6',
                      children: [
                        Div(
                          className: 'flex items-center gap-2.5 overflow-hidden',
                          children: [
                            Raw(LucideIcons.svg(LucideIconName.mail, className: 'w-4 h-4 text-indigo-400 shrink-0')),
                            Span(
                              className: 'font-mono text-xs text-zinc-200 truncate',
                              text: PortfolioPersona.email,
                            ),
                          ],
                        ),
                        Button(
                          attrs: {
                            'type': 'button',
                            ...aria(label: 'Copy email address to clipboard'),
                          },
                          className:
                              'px-2.5 py-1 rounded bg-zinc-800 hover:bg-zinc-700 text-xs font-mono text-zinc-300 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 shrink-0',
                          onClick: (_) => _copyEmailToClipboard(),
                          children: [
                            Live(() => Span(
                                  text: _copiedEmail.value ? 'Copied' : 'Copy',
                                )),
                          ],
                        ),
                      ],
                    ),

                    // Key Guarantees
                    Div(
                      className: 'flex flex-col gap-3 text-xs font-mono text-zinc-400',
                      children: [
                        _guaranteeRow(LucideIconName.check, 'Average turnaround: < 24 hours'),
                        _guaranteeRow(LucideIconName.mapPin, 'Based in San Francisco, CA (PST / UTC-8)'),
                        _guaranteeRow(LucideIconName.globe, 'Available globally for remote collaboration'),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Right Column: Validated Reactive Form (7 cols)
            Div(
              className: 'lg:col-span-7',
              children: [
                Div(
                  className: 'p-6 sm:p-8 rounded-2xl bg-zinc-900/50 border border-zinc-800/90 shadow-2xl',
                  children: [
                    // Form Element
                    Form(
                      attrs: aria(role: AriaRole.form, label: 'Contact Message Form'),
                      onSubmit: (e) {
                        e.preventDefault();
                        _handleFormSubmit();
                      },
                      children: [
                        // Status Notification Banner
                        Live(() {
                          final msg = _statusMessage.value;
                          if (msg == null) return const Fragment(children: []);
                          final success = _isSuccess.value;
                          return Div(
                            attrs: aria(role: AriaRole.alert, live: AriaLive.polite),
                            className: cx([
                              'p-4 rounded-xl mb-6 text-sm font-medium border flex items-start gap-3 transition-all',
                              success
                                  ? 'bg-emerald-950/50 border-emerald-500/40 text-emerald-300'
                                  : 'bg-rose-950/50 border-rose-500/40 text-rose-300',
                            ]),
                            children: [
                              Raw(LucideIcons.svg(
                                success ? LucideIconName.checkCircle2 : LucideIconName.alertCircle,
                                className: 'w-5 h-5 shrink-0 mt-0.5',
                              )),
                              Span(className: 'leading-relaxed', text: msg),
                            ],
                          );
                        }),

                        // Name Input Field
                        Div(
                          className: 'mb-5',
                          children: [
                            Label(
                              htmlFor: 'contact-name',
                              className: 'block font-mono text-xs font-semibold text-zinc-300 uppercase tracking-wider mb-2',
                              text: 'Full Name *',
                            ),
                            Live(() {
                              final hasError = _nameField.isTouched.value && _nameField.errors.value.isNotEmpty;
                              return Input(
                                attrs: {
                                  'id': 'contact-name',
                                  'type': 'text',
                                  'name': 'name',
                                  'placeholder': 'Ada Lovelace',
                                  'autocomplete': 'name',
                                  ...aria(
                                    required: true,
                                    invalid: hasError,
                                    describedBy: hasError ? 'name-error' : null,
                                  ),
                                },
                                value: _nameField.value.value,
                                onInput: (e) {
                                  _nameField.setValue(e.value ?? '');
                                  if (_nameField.isTouched.value) _nameField.validate();
                                },
                                onBlur: (_) {
                                  _nameField.touch();
                                  _nameField.validate();
                                },
                                className: cx([
                                  'w-full px-4 py-3 rounded-xl border text-sm transition-all focus:outline-none focus:ring-2',
                                  hasError
                                      ? 'border-rose-500/80 bg-rose-500/5 focus:ring-rose-500/30 text-rose-100 placeholder-rose-400/50'
                                      : 'border-zinc-800 bg-zinc-950/80 text-zinc-100 placeholder-zinc-600 focus:border-indigo-500 focus:ring-indigo-500/20',
                                ]),
                              );
                            }),
                            Live(() {
                              final errors = _nameField.errors.value;
                              if (!_nameField.isTouched.value || errors.isEmpty) {
                                return const Fragment(children: []);
                              }
                              return P(
                                attrs: {'id': 'name-error', ...aria(role: AriaRole.alert)},
                                className: 'mt-1.5 text-xs text-rose-400 font-medium',
                                text: errors.first,
                              );
                            }),
                          ],
                        ),

                        // Email Input Field
                        Div(
                          className: 'mb-5',
                          children: [
                            Label(
                              htmlFor: 'contact-email',
                              className: 'block font-mono text-xs font-semibold text-zinc-300 uppercase tracking-wider mb-2',
                              text: 'Email Address *',
                            ),
                            Live(() {
                              final hasError = _emailField.isTouched.value && _emailField.errors.value.isNotEmpty;
                              return Input(
                                attrs: {
                                  'id': 'contact-email',
                                  'type': 'email',
                                  'name': 'email',
                                  'placeholder': 'ada@example.com',
                                  'autocomplete': 'email',
                                  ...aria(
                                    required: true,
                                    invalid: hasError,
                                    describedBy: hasError ? 'email-error' : null,
                                  ),
                                },
                                value: _emailField.value.value,
                                onInput: (e) {
                                  _emailField.setValue(e.value ?? '');
                                  if (_emailField.isTouched.value) _emailField.validate();
                                },
                                onBlur: (_) {
                                  _emailField.touch();
                                  _emailField.validate();
                                },
                                className: cx([
                                  'w-full px-4 py-3 rounded-xl border text-sm transition-all focus:outline-none focus:ring-2',
                                  hasError
                                      ? 'border-rose-500/80 bg-rose-500/5 focus:ring-rose-500/30 text-rose-100 placeholder-rose-400/50'
                                      : 'border-zinc-800 bg-zinc-950/80 text-zinc-100 placeholder-zinc-600 focus:border-indigo-500 focus:ring-indigo-500/20',
                                ]),
                              );
                            }),
                            Live(() {
                              final errors = _emailField.errors.value;
                              if (!_emailField.isTouched.value || errors.isEmpty) {
                                return const Fragment(children: []);
                              }
                              return P(
                                attrs: {'id': 'email-error', ...aria(role: AriaRole.alert)},
                                className: 'mt-1.5 text-xs text-rose-400 font-medium',
                                text: errors.first,
                              );
                            }),
                          ],
                        ),

                        // Message Textarea Field
                        Div(
                          className: 'mb-6',
                          children: [
                            Label(
                              htmlFor: 'contact-message',
                              className: 'block font-mono text-xs font-semibold text-zinc-300 uppercase tracking-wider mb-2',
                              text: 'Project Outline / Message *',
                            ),
                            Live(() {
                              final hasError = _messageField.isTouched.value && _messageField.errors.value.isNotEmpty;
                              return Textarea(
                                rows: 5,
                                attrs: {
                                  'id': 'contact-message',
                                  'name': 'message',
                                  'placeholder':
                                      'Tell me about your system requirements, timeline, or engineering challenges...',
                                  ...aria(
                                    required: true,
                                    invalid: hasError,
                                    describedBy: hasError ? 'message-error' : null,
                                  ),
                                },
                                value: _messageField.value.value,
                                onInput: (e) {
                                  _messageField.setValue(e.value ?? '');
                                  if (_messageField.isTouched.value) _messageField.validate();
                                },
                                onBlur: (_) {
                                  _messageField.touch();
                                  _messageField.validate();
                                },
                                className: cx([
                                  'w-full px-4 py-3 rounded-xl border text-sm transition-all focus:outline-none focus:ring-2 resize-y',
                                  hasError
                                      ? 'border-rose-500/80 bg-rose-500/5 focus:ring-rose-500/30 text-rose-100 placeholder-rose-400/50'
                                      : 'border-zinc-800 bg-zinc-950/80 text-zinc-100 placeholder-zinc-600 focus:border-indigo-500 focus:ring-indigo-500/20',
                                ]),
                              );
                            }),
                            Live(() {
                              final errors = _messageField.errors.value;
                              if (!_messageField.isTouched.value || errors.isEmpty) {
                                return const Fragment(children: []);
                              }
                              return P(
                                attrs: {'id': 'message-error', ...aria(role: AriaRole.alert)},
                                className: 'mt-1.5 text-xs text-rose-400 font-medium',
                                text: errors.first,
                              );
                            }),
                          ],
                        ),

                        // Form Submit Button
                        Live(() {
                          final submitting = _form.isSubmitting.value;
                          final hasErrors = _form.isDirty.value && !_form.isValid.value;
                          final disabled = submitting || hasErrors;

                          return Button(
                            attrs: {
                              'type': 'submit',
                              if (disabled) 'disabled': 'true',
                              ...aria(
                                busy: submitting,
                                disabled: disabled,
                                label: submitting ? 'Transmitting message...' : 'Transmit message',
                              ),
                            },
                            className: cx([
                              'w-full inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl font-semibold text-sm transition-all shadow-lg focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
                              disabled
                                  ? 'bg-zinc-800 text-zinc-500 cursor-not-allowed border border-zinc-700/40 shadow-none'
                                  : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-600/25 hover:shadow-indigo-600/40 hover:-translate-y-0.5',
                            ]),
                            children: [
                              if (submitting)
                                Span(
                                  className:
                                      'w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin',
                                )
                              else
                                Raw(LucideIcons.svg(LucideIconName.send, className: 'w-4 h-4')),
                              Span(text: submitting ? 'Transmitting Message...' : 'Send Message'),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  BloomNode _guaranteeRow(LucideIconName icon, String text) {
    return Div(
      className: 'flex items-center gap-2.5',
      children: [
        Raw(LucideIcons.svg(icon, className: 'w-4 h-4 text-emerald-400 shrink-0')),
        Span(className: 'text-zinc-300', text: text),
      ],
    );
  }

  void _copyEmailToClipboard() {
    try {
      _copiedEmail.value = true;
      Future.delayed(const Duration(seconds: 3), () {
        _copiedEmail.value = false;
      });
    } catch (_) {}
  }

  Future<void> _handleFormSubmit() async {
    _statusMessage.value = null;

    await _form.submit((values) async {
      // Check if real EmailJS credentials have been supplied
      if (!EmailJsConfig.isConfigured) {
        // Graceful Demo Mode: simulate transmission
        await Future.delayed(const Duration(milliseconds: 600));
        Confetti.burst(x: 0.5, y: 0.6);
        _isSuccess.value = true;
        _statusMessage.value =
            'Message delivered in demo mode! (To connect live email dispatch, add your EmailJS keys in lib/config.dart).';
        _form.reset();
        return;
      }

      // Live EmailJS dispatch
      final sent = await EmailJs.send(
        serviceId: EmailJsConfig.serviceId,
        templateId: EmailJsConfig.templateId,
        publicKey: EmailJsConfig.publicKey,
        templateParams: {
          'name': values['name'] ?? '',
          'email': values['email'] ?? '',
          'message': values['message'] ?? '',
        },
      );

      if (sent) {
        Confetti.burst(x: 0.5, y: 0.6);
        _isSuccess.value = true;
        _statusMessage.value =
            'Thank you for reaching out! Your message was sent successfully. I will get back to you shortly.';
        _form.reset();
      } else {
        _isSuccess.value = false;
        _statusMessage.value =
            'Unable to transmit message via EmailJS. Please retry or contact directly at ${PortfolioPersona.email}.';
      }
    });
  }
}
