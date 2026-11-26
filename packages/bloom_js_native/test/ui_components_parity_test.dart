import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/ui.dart';
import 'package:test/test.dart';

void main() {
  group('UI Parity Primitives & Composites', () {
    test('buttonGroup and buttonGroupText render group semantics', () {
      final html = renderToHtml(buttonGroup(
        orientation: ButtonGroupOrientation.vertical,
        children: [
          buttonGroupText(text: 'https://'),
          button(text: 'Copy'),
        ],
      ));
      expect(html, contains('role="group"'));
      expect(html, contains('data-orientation="vertical"'));
      expect(html, contains('https://'));
      expect(html, contains('Copy'));
    });

    test('carousel renders active slide and cycles with controls', () {
      final index = signal(0);
      final tree = carousel(
        activeIndex: index,
        items: [
          carouselItem(child: P(text: 'Slide 1')),
          carouselItem(child: P(text: 'Slide 2')),
        ],
      );
      final r = renderForTest(tree);
      expect(r.toHtml(), contains('Slide 1'));
      expect(r.toHtml(), contains('aria-roledescription="carousel"'));

      fireEvent.click(r.getByTag('button'));
      expect(index.value, 1);
      expect(r.toHtml(), contains('Slide 2'));
    });

    test('collapsible toggles content visibility', () {
      final open = signal(false);
      final tree = collapsible(
        open: open,
        trigger: Button(
          text: 'Toggle',
          attrs: const {'data-testid': 'trigger'},
        ),
        content: P(text: 'Secret details'),
      );
      final r = renderForTest(tree);
      expect(r.toHtml(), isNot(contains('Secret details')));

      fireEvent.click(r.getByTestId('collapsible-trigger'));
      expect(open.value, isTrue);
      expect(r.toHtml(), contains('Secret details'));
    });

    test('combobox selects option and updates selected signal', () {
      final selected = signal<String?>(null);
      final tree = combobox(
        selected: selected,
        options: const [
          ComboboxOption(value: 'dart', label: 'Dart'),
          ComboboxOption(value: 'rust', label: 'Rust'),
        ],
      );
      final r = renderForTest(tree);
      expect(r.toHtml(), contains('Select option...'));
      fireEvent.click(r.getByTag('button'));
      expect(r.toHtml(), contains('Dart'));
      expect(r.toHtml(), contains('data-value="dart"'));

      ElNode? findOpt(BloomNode n) {
        if (n is ElNode && n.attrs?['data-value'] == 'dart') return n;
        if (n is ElNode) {
          for (final c in n.children) {
            final f = findOpt(c);
            if (f != null) return f;
          }
        } else if (n is ShowNode && n.when()) {
          return findOpt(n.child);
        } else if (n is LiveNode) {
          return findOpt(n.builder());
        } else if (n is FragmentNode) {
          for (final c in n.children) {
            final f = findOpt(c);
            if (f != null) return f;
          }
        }
        return null;
      }

      fireEvent.click(findOpt(tree)!);
      expect(selected.value, 'dart');
    });

    test('direction sets dir attribute', () {
      final html = renderToHtml(direction(
        dir: UiTextDirection.rtl,
        children: [P(text: 'مرحبا')],
      ));
      expect(html, contains('dir="rtl"'));
    });

    test('empty and emptyState render status container', () {
      final html = renderToHtml(empty(
        title: 'No items',
        description: 'Create your first item.',
        icon: 'inbox',
      ));
      expect(html, contains('role="status"'));
      expect(html, contains('No items'));

      final aliasHtml = renderToHtml(emptyState(title: 'Empty alias'));
      expect(aliasHtml, contains('Empty alias'));
    });

    test('uiItem and kbd / kbdGroup render expected markup', () {
      final itemHtml = renderToHtml(uiItem(
        title: 'Profile',
        subtitle: 'Manage account',
        active: true,
        trailing: kbdGroup(keys: const ['Cmd', 'K']),
      ));
      expect(itemHtml, contains('Profile'));
      expect(itemHtml, contains('aria-current="true"'));
      expect(itemHtml, contains('<kbd'));
      expect(itemHtml, contains('Cmd'));
    });

    test('sidebar, appShell, and dashboardShell render layout landmarks', () {
      final nav = sidebar(
        header: Span(text: 'Bloom'),
        children: [
          sidebarGroup(
            label: 'Main',
            children: [
              sidebarItem(label: 'Home', href: '/', active: true),
            ],
          ),
        ],
      );
      final shellHtml = renderToHtml(appShell(
        header: Span(text: 'Top'),
        sidebar: nav,
        body: P(text: 'Content'),
        footer: Span(text: 'Bottom'),
      ));
      expect(shellHtml, contains('<aside'));
      expect(shellHtml, contains('<main'));
      expect(shellHtml, contains('<header'));
      expect(shellHtml, contains('<footer'));

      final dashHtml = renderToHtml(dashboardShell(
        sidebar: nav,
        topBar: Span(text: 'Bar'),
        content: P(text: 'Dash'),
      ));
      expect(dashHtml, contains('Dash'));
    });

    test('typography, spinner, toastBanner, and banner render cleanly', () {
      final html = renderToHtml(Fragment(children: [
        uiH1('Title'),
        uiH2('Section'),
        uiH3('Sub'),
        uiH4('Minor'),
        uiP('Body'),
        uiLead('Lead'),
        uiMuted('Muted'),
        uiBlockquote('Quote'),
        uiInlineCode('code()'),
        spinner(size: SpinnerSize.lg),
        toastBanner(title: 'Saved', variant: ToastVariant.success),
        banner(message: 'Notice', variant: BannerVariant.warning),
      ]));
      expect(html, contains('<h1'));
      expect(html, contains('<blockquote'));
      expect(html, contains('<code'));
      expect(html, contains('Saved'));
      expect(html, contains('Notice'));
    });

    test('authForm submits email and password', () {
      final email = signal('a@b.com');
      final password = signal('secret123');
      String? submittedEmail;
      final tree = authForm(
        email: email,
        password: password,
        onSubmit: (e, p) => submittedEmail = e,
      );
      final r = renderForTest(tree);
      fireEvent.submit(r.getByTag('form'));
      expect(submittedEmail, 'a@b.com');
    });

    test('dataTable renders rows and sorts on column click', () {
      final tree = dataTable<({String name, int score})>(
        columns: [
          DataTableColumn(
            id: 'name',
            header: 'Name',
            cell: (r) => Text(r.name),
            sortBy: (r) => r.name,
          ),
          DataTableColumn(
            id: 'score',
            header: 'Score',
            cell: (r) => Text('${r.score}'),
            sortBy: (r) => r.score,
          ),
        ],
        rows: const [
          (name: 'Zoe', score: 10),
          (name: 'Ada', score: 20),
        ],
        searchText: (r) => r.name,
      );
      final r = renderForTest(tree);
      expect(r.toHtml(), contains('Zoe'));
      expect(r.toHtml(), contains('Ada'));

      fireEvent.click(r.getByText('Name') as ElNode);
      final sortedHtml = r.toHtml();
      expect(sortedHtml.indexOf('Ada'), lessThan(sortedHtml.indexOf('Zoe')));
    });

    test('datePicker, errorState, and loadingState render', () {
      final date = signal<DateTime?>(DateTime(2026, 11, 26));
      final html = renderToHtml(Fragment(children: [
        datePicker(selected: date),
        errorState(message: 'Failed', onRetry: (_) {}),
        loadingState(useSkeleton: true, skeletonRows: 2),
      ]));
      expect(html, contains('2026-11-26'));
      expect(html, contains('Try again'));
      expect(html, contains('animate-pulse'));
    });

    test('filterBar toggles selected chips and clears', () {
      final selected = signal<Set<String>>({'open'});
      final tree = filterBar(
        selected: selected,
        options: const [
          FilterChipOption(value: 'open', label: 'Open', count: 3),
          FilterChipOption(value: 'closed', label: 'Closed', count: 1),
        ],
      );
      final r = renderForTest(tree);
      ElNode findFilter(BloomNode n, String val) {
        if (n is ElNode && n.attrs?['data-filter-value'] == val) return n;
        if (n is LiveNode) return findFilter(n.builder(), val);
        if (n is ElNode) {
          for (final c in n.children) {
            try {
              return findFilter(c, val);
            } catch (_) {}
          }
        }
        throw StateError('Filter $val not found');
      }

      fireEvent.click(findFilter(tree, 'closed'));
      expect(selected.value, {'open', 'closed'});
      fireEvent.click(r.getByText('Clear') as ElNode);
      expect(selected.value, isEmpty);
    });

    test('multiSelect, phoneInput, pricingCard, searchBar, settings, tagsInput',
        () {
      final multi = signal<List<String>>(['a']);
      final tags = signal<List<String>>(['dart', 'web']);
      final query = signal<String>('bloom');
      final dial = signal<String>('+1');
      final num = signal<String>('5550100');

      final html = renderToHtml(Fragment(children: [
        multiSelect(
          selected: multi,
          options: const [
            MultiSelectOption(value: 'a', label: 'Alpha'),
            MultiSelectOption(value: 'b', label: 'Beta'),
          ],
        ),
        phoneInput(countryDialCode: dial, number: num),
        pricingCard(
          tier: 'Pro',
          price: '\$29',
          features: const ['SSR', 'ISR'],
          ctaLabel: 'Upgrade',
          highlighted: true,
          badgeText: 'Popular',
        ),
        searchBar(query: query, shortcutHint: '/'),
        settingsSection(
          title: 'General',
          children: [
            settingsTile(
              title: 'Dark mode',
              control: switchToggle(checked: true, onChange: (_) {}),
            ),
          ],
        ),
        tagsInput(tags: tags),
      ]));

      expect(html, contains('Alpha'));
      expect(html, contains('+1'));
      expect(html, contains('Upgrade'));
      expect(html, contains('Popular'));
      expect(html, contains('Dark mode'));
      expect(html, contains('dart'));
    });
  });
}
