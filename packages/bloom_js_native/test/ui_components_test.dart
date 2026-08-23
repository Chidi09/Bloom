import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('UI Components', () {
    test('cn helper filters null, false, and empty strings', () {
      expect(cn(['foo', null, false, '', 'bar', '   ', 'baz']), 'foo bar baz');
    });

    test('button renders button and link properly', () {
      final btnHtml = renderToHtml(button(text: 'Click me', variant: ButtonVariant.primary));
      expect(btnHtml, contains('<button'));
      expect(btnHtml, contains('Click me'));
      expect(btnHtml, contains('bg-[var(--primary)]'));

      final linkBtnHtml = renderToHtml(button(text: 'Visit', href: '/dashboard', variant: ButtonVariant.outline));
      expect(linkBtnHtml, contains('<a'));
      expect(linkBtnHtml, contains('href="/dashboard"'));
      expect(linkBtnHtml, contains('Visit'));
      expect(linkBtnHtml, contains('border-[var(--border)]'));
    });

    test('input renders with placeholder and error state', () {
      final inputHtml = renderToHtml(textInput(id: 'email', placeholder: 'user@example.com', hasError: true));
      expect(inputHtml, contains('id="email"'));
      expect(inputHtml, contains('placeholder="user@example.com"'));
      expect(inputHtml, contains('border-[var(--destructive)]'));
      expect(inputHtml, contains('aria-invalid="true"'));
    });

    test('label renders correctly with required indicator', () {
      final lblHtml = renderToHtml(label(text: 'Username', htmlFor: 'uname', required: true));
      expect(lblHtml, contains('<label'));
      expect(lblHtml, contains('for="uname"'));
      expect(lblHtml, contains('Username'));
      expect(lblHtml, contains('*'));
    });

    test('card and its subcomponents render structured markup', () {
      final cardHtml = renderToHtml(card(
        children: [
          cardHeader(
            children: [
              cardTitle(text: 'Account Settings'),
              cardDescription(text: 'Manage your profile and security preferences.'),
            ],
          ),
          cardContent(
            children: [
              textInput(id: 'full_name', value: 'Jane Doe'),
            ],
          ),
          cardFooter(
            children: [
              button(text: 'Save'),
            ],
          ),
        ],
      ));

      expect(cardHtml, contains('Account Settings'));
      expect(cardHtml, contains('Manage your profile'));
      expect(cardHtml, contains('Jane Doe'));
      expect(cardHtml, contains('Save'));
      expect(cardHtml, contains('rounded-[var(--radius-lg)]'));
    });

    test('badge renders semantic variants', () {
      final b1 = renderToHtml(badge(label: 'Active', variant: BadgeVariant.success));
      expect(b1, contains('Active'));
      expect(b1, contains('bg-[var(--success)]'));

      final b2 = renderToHtml(badge(label: 'Destructive', variant: BadgeVariant.destructive));
      expect(b2, contains('bg-[var(--destructive)]'));
    });

    test('checkbox renders with label', () {
      final cbHtml = renderToHtml(checkbox(id: 'agree', checked: true, label: 'I agree'));
      expect(cbHtml, contains('type="checkbox"'));
      expect(cbHtml, contains('checked="checked"'));
      expect(cbHtml, contains('I agree'));
    });

    test('textarea renders rows and error class', () {
      final taHtml = renderToHtml(textarea(id: 'bio', rows: 6, value: 'Hello world', hasError: true));
      expect(taHtml, contains('rows="6"'));
      expect(taHtml, contains('border-[var(--destructive)]'));
      expect(taHtml, contains('Hello world'));
    });

    test('select renders options with selected value', () {
      final selHtml = renderToHtml(selectInput(
        id: 'role',
        value: 'admin',
        options: [
          (value: 'user', label: 'User'),
          (value: 'admin', label: 'Administrator'),
        ],
      ));
      expect(selHtml, contains('<select'));
      expect(selHtml, contains('id="role"'));
      expect(selHtml, contains('value="admin" selected="selected"'));
    });

    test('separator renders horizontal and vertical dividers', () {
      final hSep = renderToHtml(separator());
      expect(hSep, contains('aria-orientation="horizontal"'));
      expect(hSep, contains('h-px w-full'));

      final vSep = renderToHtml(separator(vertical: true));
      expect(vSep, contains('aria-orientation="vertical"'));
      expect(vSep, contains('w-px h-full'));
    });

    test('avatar renders image when src provided and fallback when not', () {
      final imgAv = renderToHtml(avatar(src: 'https://example.com/pic.png', alt: 'Jane'));
      expect(imgAv, contains('<img'));
      expect(imgAv, contains('src="https://example.com/pic.png"'));

      final fallbackAv = renderToHtml(avatar(fallbackText: 'JD'));
      expect(fallbackAv, contains('JD'));
    });

    test('tabs renders tab list and active tab content', () {
      final tabsHtml = renderToHtml(tabs(
        items: [
          (key: 'overview', label: 'Overview'),
          (key: 'billing', label: 'Billing'),
        ],
        activeKey: 'billing',
        onChange: (_) {},
        content: (key) => Div(text: 'Active panel: $key'),
      ));
      expect(tabsHtml, contains('Overview'));
      expect(tabsHtml, contains('Billing'));
      expect(tabsHtml, contains('Active panel: billing'));
    });

    test('dialog and alert dialog work with activeDialog signal and viewport', () {
      openConfirmDialog(
        title: 'Delete Item',
        description: 'Are you sure?',
        destructive: true,
        onConfirm: () {},
      );

      final dialogHtml = renderToHtml(dialogViewport());
      expect(dialogHtml, contains('Delete Item'));
      expect(dialogHtml, contains('Are you sure?'));
      expect(dialogHtml, contains('bg-[var(--destructive)]'));

      closeDialog();
      final emptyDialogHtml = renderToHtml(dialogViewport());
      expect(emptyDialogHtml, isNot(contains('Delete Item')));
    });

    test('alert renders title and description with icon', () {
      final alertHtml = renderToHtml(alert(
        title: 'Notice',
        description: 'System maintenance scheduled.',
        variant: AlertVariant.warning,
      ));
      expect(alertHtml, contains('Notice'));
      expect(alertHtml, contains('System maintenance scheduled.'));
      expect(alertHtml, contains('role="alert"'));
    });

    test('tooltip wraps child element', () {
      final ttHtml = renderToHtml(tooltip(label: 'Help text', child: button(text: 'Hover me')));
      expect(ttHtml, contains('Hover me'));
      expect(ttHtml, contains('Help text'));
      expect(ttHtml, contains('group/tt'));
    });

    test('dropdownMenu renders trigger', () {
      final ddHtml = renderToHtml(dropdownMenu(
        trigger: button(text: 'Actions'),
        items: [
          const MenuItemConfig(label: 'Edit'),
          const MenuItemConfig(label: 'Delete', destructive: true),
        ],
      ));
      expect(ddHtml, contains('Actions'));
    });

    test('popover renders trigger', () {
      final popHtml = renderToHtml(popover(
        trigger: button(text: 'Open Popover'),
        content: Div(text: 'Popover contents'),
      ));
      expect(popHtml, contains('Open Popover'));
    });

    test('progress renders percentage track', () {
      final progHtml = renderToHtml(progress(value: 65, max: 100, label: 'Uploading', showValue: true));
      expect(progHtml, contains('role="progressbar"'));
      expect(progHtml, contains('Uploading'));
      expect(progHtml, contains('65%'));
      expect(progHtml, contains('width: 65'));
    });

    test('skeleton renders placeholder with pulse animation', () {
      final skelHtml = renderToHtml(skeleton(extraClassName: 'w-24 h-4'));
      expect(skelHtml, contains('animate-pulse'));
      expect(skelHtml, contains('w-24 h-4'));
    });

    test('switchToggle renders switch button with checked state', () {
      final swHtml = renderToHtml(switchToggle(checked: true, onChange: (_) {}));
      expect(swHtml, contains('role="switch"'));
      expect(swHtml, contains('aria-checked="true"'));
      expect(swHtml, contains('translate-x-4'));
    });

    test('radioGroup renders radio options', () {
      final rgHtml = renderToHtml(radioGroup(
        name: 'plan',
        value: 'pro',
        options: [
          (value: 'starter', label: 'Starter'),
          (value: 'pro', label: 'Pro Plan'),
        ],
        onChange: (_) {},
      ));
      expect(rgHtml, contains('role="radiogroup"'));
      expect(rgHtml, contains('value="pro" checked="checked"'));
      expect(rgHtml, contains('Pro Plan'));
    });

    test('table family renders semantic HTML table structure', () {
      final tblHtml = renderToHtml(table(
        children: [
          tableHeader(children: [
            tableRow(children: [
              tableHead(text: 'Name'),
              tableHead(text: 'Role'),
            ]),
          ]),
          tableBody(children: [
            tableRow(children: [
              tableCell(text: 'Alice'),
              tableCell(text: 'Engineer'),
            ]),
          ]),
        ],
      ));
      expect(tblHtml, contains('<table'));
      expect(tblHtml, contains('<thead'));
      expect(tblHtml, contains('<tbody'));
      expect(tblHtml, contains('<tr'));
      expect(tblHtml, contains('<th'));
      expect(tblHtml, contains('<td'));
      expect(tblHtml, contains('Alice'));
      expect(tblHtml, contains('Engineer'));
    });

    test('breadcrumb renders breadcrumb nav', () {
      final bcHtml = renderToHtml(breadcrumb([
        (label: 'Home', href: '/'),
        (label: 'Products', href: '/products'),
        (label: 'Shoes', href: null),
      ]));
      expect(bcHtml, contains('aria-label="Breadcrumb"'));
      expect(bcHtml, contains('href="/"'));
      expect(bcHtml, contains('href="/products"'));
      expect(bcHtml, contains('Shoes'));
    });

    test('paginationBar renders cursor navigation controls', () {
      final pagHtml = renderToHtml(paginationBar(
        currentPath: '/items',
        currentQuery: const {'back': '~'},
        total: 50,
        itemCount: 24,
        nextCursor: 'cur_abc',
      ));
      expect(pagHtml, contains('role="navigation"'));
      expect(pagHtml, contains('Previous'));
      expect(pagHtml, contains('Next'));
      expect(pagHtml, contains('cursor=cur_abc'));
    });

    test('sonner toast works with showToast and toastViewport', () {
      showToast('Profile updated!', variant: ToastVariant.success);
      final toastHtml = renderToHtml(toastViewport());
      expect(toastHtml, contains('Profile updated!'));
      expect(toastHtml, contains('border-[var(--success)]'));
    });

    test('field and formField render label, control and error message', () {
      final fHtml = renderToHtml(formField(
        id: 'email',
        label: 'Email Address',
        control: textInput(id: 'email', value: 'bad-email'),
        error: 'Please enter a valid email.',
      ));
      expect(fHtml, contains('Email Address'));
      expect(fHtml, contains('bad-email'));
      expect(fHtml, contains('Please enter a valid email.'));
      expect(fHtml, contains('id="email-help"'));
    });

    test('inputGroup groups addons with input control', () {
      final igHtml = renderToHtml(inputGroup(
        children: [
          inputGroupAddon(children: [inputGroupText(text: 'https://')]),
          textInput(id: 'subdomain', placeholder: 'acme'),
          inputGroupAddon(align: 'right', children: [inputGroupText(text: '.bloom.dev')]),
        ],
      ));
      expect(igHtml, contains('https://'));
      expect(igHtml, contains('placeholder="acme"'));
      expect(igHtml, contains('.bloom.dev'));
    });
  });
}
