import 'dart:io';

import 'package:bloom_mail/bloom_mail.dart';
import 'package:test/test.dart';

void main() {
  group('BloomMailTemplate - Variable Interpolation & Filters', () {
    test('renders simple variables', () {
      final template = BloomMailTemplate('Hello, {{ name }}!');
      final result = template.render({'name': 'Bloom'});
      expect(result, equals('Hello, Bloom!'));
    });

    test('supports nested dot notation lookups', () {
      final template = BloomMailTemplate(
        'User: {{ user.profile.first_name }} {{ user.profile.last_name }} ({{ user.email }})',
      );
      final result = template.render({
        'user': {
          'email': 'alice@example.com',
          'profile': {
            'first_name': 'Alice',
            'last_name': 'Smith',
          },
        },
      });
      expect(result, equals('User: Alice Smith (alice@example.com)'));
    });

    test('missing variables evaluate to empty string and do not throw', () {
      final template = BloomMailTemplate(
          'Name: [{{ missing }}], Nested: [{{ user.nonexistent }}]');
      final result = template.render({
        'user': {'name': 'Alice'}
      });
      expect(result, equals('Name: [], Nested: []'));
    });

    test('auto-escapes HTML entities in HTML templates by default', () {
      final template = BloomMailTemplate('<b>{{ alert }}</b>', isHtml: true);
      final result =
          template.render({'alert': '<script>alert("XSS & fun")</script>'});
      expect(
        result,
        equals(
            '<b>&lt;script&gt;alert(&quot;XSS &amp; fun&quot;)&lt;&#x2F;script&gt;</b>'),
      );
    });

    test('bypasses escaping with safe filter, raw filter, and SafeHtml wrapper',
        () {
      final template = BloomMailTemplate(
        'Safe filter: {{ link1 | safe }}, Raw filter: {{ link2 | raw }}, SafeHtml: {{ link3 }}',
        isHtml: true,
      );
      final result = template.render({
        'link1': '<a href="https://example.com?a=1&b=2">Click</a>',
        'link2': '<span>Raw</span>',
        'link3': const SafeHtml('<div>Safe</div>'),
      });
      expect(
        result,
        equals(
            'Safe filter: <a href="https://example.com?a=1&b=2">Click</a>, Raw filter: <span>Raw</span>, SafeHtml: <div>Safe</div>'),
      );
    });

    test('does not HTML-escape variables in plain-text templates', () {
      final template =
          BloomMailTemplate.text('Link: {{ url }} & Subject: {{ subject }}');
      final result = template.render({
        'url': 'https://example.com/reset?user=1&token=xyz',
        'subject': 'Alert <Important>',
      });
      expect(
          result,
          equals(
              'Link: https://example.com/reset?user=1&token=xyz & Subject: Alert <Important>'));
    });

    test('supports standard filters (upper, lower, trim, length, default)', () {
      final template = BloomMailTemplate(
        '{{ title | upper }} / {{ title | lower }} / {{ padded | trim }} / Count: {{ list | length }} / {{ missing | default:"N/A" }}',
        isHtml: false,
      );
      final result = template.render({
        'title': 'Hello World',
        'padded': '   spaced   ',
        'list': ['a', 'b', 'c'],
      });
      expect(result,
          equals('HELLO WORLD / hello world / spaced / Count: 3 / N/A'));
    });

    test('strips template comments', () {
      final template = BloomMailTemplate(
        'Start{# This is an inline comment #}Middle{% comment %}Multi-line\ncomment{% endcomment %}End',
      );
      final result = template.render({});
      expect(result, equals('StartMiddleEnd'));
    });
  });

  group('BloomMailTemplate - Conditionals ({% if %})', () {
    test('evaluates truthy and falsy variables', () {
      final template = BloomMailTemplate(
        '{% if is_admin %}Admin{% else %}User{% endif %}',
      );
      expect(template.render({'is_admin': true}), equals('Admin'));
      expect(template.render({'is_admin': false}), equals('User'));
      expect(template.render({'is_admin': null}), equals('User'));
      expect(template.render({}), equals('User'));
      expect(template.render({'is_admin': ''}), equals('User'));
      expect(template.render({'is_admin': 'yes'}), equals('Admin'));
      expect(template.render({'is_admin': []}), equals('User'));
      expect(
          template.render({
            'is_admin': [1]
          }),
          equals('Admin'));
    });

    test('supports {% if not %}', () {
      final template = BloomMailTemplate(
          '{% if not is_verified %}Please verify your email{% endif %}');
      expect(template.render({'is_verified': false}),
          equals('Please verify your email'));
      expect(template.render({'is_verified': true}), equals(''));
    });

    test('supports {% elif %} chains', () {
      final template = BloomMailTemplate(
        '{% if role == "admin" %}Administrator{% elif role == "editor" %}Editor{% else %}Viewer{% endif %}',
      );
      expect(template.render({'role': 'admin'}), equals('Administrator'));
      expect(template.render({'role': 'editor'}), equals('Editor'));
      expect(template.render({'role': 'other'}), equals('Viewer'));
    });

    test('supports numeric and comparison operators (==, !=, <, <=, >, >=)',
        () {
      final template = BloomMailTemplate(
        '{% if count > 0 %}Positive{% elif count == 0 %}Zero{% else %}Negative{% endif %}',
      );
      expect(template.render({'count': 5}), equals('Positive'));
      expect(template.render({'count': 0}), equals('Zero'));
      expect(template.render({'count': -2}), equals('Negative'));
    });

    test('supports logical and / or operators', () {
      final template = BloomMailTemplate(
        '{% if is_active and is_verified %}Full Access{% elif is_active or is_guest %}Limited Access{% else %}No Access{% endif %}',
      );
      expect(template.render({'is_active': true, 'is_verified': true}),
          equals('Full Access'));
      expect(template.render({'is_active': false, 'is_guest': true}),
          equals('Limited Access'));
      expect(template.render({'is_active': false, 'is_guest': false}),
          equals('No Access'));
    });

    test('handles nested conditionals', () {
      final template = BloomMailTemplate(
        '{% if outer %}[Outer-Start:{% if inner %}Inner{% else %}No-Inner{% endif %}:Outer-End]{% endif %}',
      );
      expect(template.render({'outer': true, 'inner': true}),
          equals('[Outer-Start:Inner:Outer-End]'));
      expect(template.render({'outer': true, 'inner': false}),
          equals('[Outer-Start:No-Inner:Outer-End]'));
      expect(template.render({'outer': false, 'inner': true}), equals(''));
    });
  });

  group('BloomMailTemplate - Loops ({% for %})', () {
    test('iterates over lists with forloop variables', () {
      final template = BloomMailTemplate(
        '{% for item in items %}{{ forloop.index }}: {{ item }}{% if not forloop.last %}, {% endif %}{% endfor %}',
      );
      final result = template.render({
        'items': ['apple', 'banana', 'cherry'],
      });
      expect(result, equals('1: apple, 2: banana, 3: cherry'));
    });

    test('forloop variables: index0, first, last, length', () {
      final template = BloomMailTemplate(
        '{% for x in list %}[i0={{ forloop.index0 }} first={{ forloop.first }} last={{ forloop.last }} len={{ forloop.length }} val={{ x }}]{% endfor %}',
      );
      final result = template.render({
        'list': ['a', 'b'],
      });
      expect(
          result,
          equals(
              '[i0=0 first=true last=false len=2 val=a][i0=1 first=false last=true len=2 val=b]'));
    });

    test('renders {% empty %} block when collection is empty or null', () {
      final template = BloomMailTemplate(
        '{% for item in items %}{{ item }}{% empty %}No items available.{% endfor %}',
      );
      expect(template.render({'items': []}), equals('No items available.'));
      expect(template.render({'items': null}), equals('No items available.'));
      expect(template.render({}), equals('No items available.'));
    });

    test('handles nested loops and object property access', () {
      final template = BloomMailTemplate(
        '{% for order in orders %}Order #{{ order.id }}: {% for item in order.items %}{{ item.name }} (\${{ item.price }}){% if not forloop.last %}; {% endif %}{% endfor %}\n{% endfor %}',
        isHtml: false,
      );
      final result = template.render({
        'orders': [
          {
            'id': 101,
            'items': [
              {'name': 'Widget', 'price': 10},
              {'name': 'Gadget', 'price': 20},
            ],
          },
          {
            'id': 102,
            'items': [
              {'name': 'Doohickey', 'price': 15},
            ],
          },
        ],
      });
      expect(
          result,
          equals(
              'Order #101: Widget (\$10); Gadget (\$20)\nOrder #102: Doohickey (\$15)\n'));
    });
  });

  group('BloomMailTemplate - Companion Plain-Text Template & Disk Loading', () {
    test('loads from string with companion text template', () {
      final template = BloomMailTemplate.fromString(
        '<h1>Hello {{ name }}</h1>',
        textSource: 'Hello {{ name }}',
      );
      expect(template.isHtml, isTrue);
      expect(template.textTemplate, isNotNull);
      expect(template.textTemplate!.isHtml, isFalse);

      final context = {'name': 'Charlie'};
      expect(template.render(context), equals('<h1>Hello Charlie</h1>'));
      expect(template.renderText(context), equals('Hello Charlie'));
    });

    test('loads from disk and auto-detects companion .txt file', () {
      final tempDir = Directory.systemTemp.createTempSync('bloom_mail_test_');
      try {
        final htmlFile = File('${tempDir.path}/notification.html');
        final txtFile = File('${tempDir.path}/notification.txt');

        htmlFile.writeAsStringSync('<p>Notification for {{ user }}</p>');
        txtFile.writeAsStringSync('Notification for {{ user }}');

        final template = BloomMailTemplate.fromFile(htmlFile);
        expect(template.textTemplate, isNotNull);

        final context = {'user': 'Dana'};
        expect(
            template.render(context), equals('<p>Notification for Dana</p>'));
        expect(template.renderText(context), equals('Notification for Dana'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('loads example template files from package', () {
      final welcomePath = 'example/templates/welcome_email.html';
      final file = File(welcomePath);
      if (file.existsSync()) {
        final template = BloomMailTemplate.fromPath(welcomePath);
        final context = {
          'user': {'name': 'Alice'},
          'app_name': 'Bloom App',
          'is_admin': true,
          'onboarding_steps': ['Create a project', 'Invite team members'],
          'action_url': 'https://example.com/dashboard',
        };
        final html = template.render(context);
        final text = template.renderText(context);

        expect(html, contains('Welcome, Alice!'));
        expect(html, contains('Bloom App'));
        expect(html, contains('Create a project'));
        expect(text, contains('Welcome, Alice!'));
        expect(text, contains('https://example.com/dashboard'));
      }
    });
  });

  group('BloomMailMessage.fromTemplate & BloomTemplatedMessage', () {
    test('renders HTML and companion text into BloomMailMessage', () {
      final template = BloomMailTemplate.fromString(
        '<h1>Hello {{ user }}</h1><p>Action: <a href="{{ url|safe }}">Click</a></p>',
        textSource: 'Hello {{ user }}\nAction: {{ url }}',
      );

      final message = BloomMailMessage.fromTemplate(
        to: ['alice@example.com'],
        from: 'noreply@bloom.dev',
        subject: 'Welcome {{ user }}',
        htmlTemplate: template,
        context: {
          'user': 'Alice',
          'url': 'https://bloom.dev/start?token=123&user=alice',
        },
        cc: ['manager@example.com'],
        bcc: ['archive@example.com'],
      );

      expect(message.to, equals(['alice@example.com']));
      expect(message.from, equals('noreply@bloom.dev'));
      expect(message.subject, equals('Welcome {{ user }}'));
      expect(message.cc, equals(['manager@example.com']));
      expect(message.bcc, equals(['archive@example.com']));

      expect(
        message.htmlBody,
        equals(
            '<h1>Hello Alice</h1><p>Action: <a href="https://bloom.dev/start?token=123&user=alice">Click</a></p>'),
      );
      expect(
        message.body,
        equals(
            'Hello Alice\nAction: https://bloom.dev/start?token=123&user=alice'),
      );
    });

    test('singleFromTemplate convenience constructor', () {
      final template = BloomMailTemplate.fromString(
        '<p>Hi {{ name }}</p>',
        textSource: 'Hi {{ name }}',
      );

      final message = BloomMailMessage.singleFromTemplate(
        to: 'bob@example.com',
        from: 'noreply@bloom.dev',
        subject: 'Quick Note',
        htmlTemplate: template,
        context: {'name': 'Bob'},
      );

      expect(message.to, equals(['bob@example.com']));
      expect(message.htmlBody, equals('<p>Hi Bob</p>'));
      expect(message.body, equals('Hi Bob'));
    });

    test('BloomTemplatedMessage helper builds matching message', () {
      final htmlTpl = BloomMailTemplate.html('<h1>Hi {{ name }}</h1>');
      final textTpl = BloomMailTemplate.text('Hi {{ name }}');

      final msg = BloomTemplatedMessage.create(
        to: ['carol@example.com'],
        from: 'bot@bloom.dev',
        subject: 'Greetings',
        htmlTemplate: htmlTpl,
        textTemplate: textTpl,
        context: {'name': 'Carol'},
      );

      expect(msg.to, equals(['carol@example.com']));
      expect(msg.htmlBody, equals('<h1>Hi Carol</h1>'));
      expect(msg.body, equals('Hi Carol'));
    });

    test(
        'preserves BloomMailMessage immutability, copyWith, equality, and hashCode',
        () {
      final template = BloomMailTemplate.fromString(
        '<b>{{ val }}</b>',
        textSource: '{{ val }}',
      );

      final m1 = BloomMailMessage.fromTemplate(
        to: ['a@example.com'],
        from: 'b@example.com',
        subject: 'Sub',
        htmlTemplate: template,
        context: {'val': '123'},
      );

      final m2 = BloomMailMessage(
        to: ['a@example.com'],
        from: 'b@example.com',
        subject: 'Sub',
        body: '123',
        htmlBody: '<b>123</b>',
      );

      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));

      final m3 = m1.copyWith(subject: 'New Sub');
      expect(m3.subject, equals('New Sub'));
      expect(m3.body, equals('123'));
      expect(m3.htmlBody, equals('<b>123</b>'));
    });
  });
}
