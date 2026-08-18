export interface ComponentProp {
  name: string;
  type: string;
  defaultVal?: string;
  description: string;
}

export interface ComponentSlot {
  name: string;
  description: string;
}

export interface UIComponentDoc {
  slug: string;
  title: string;
  name: string;
  category: 'Form Controls' | 'Layout & Structure' | 'Feedback & Overlays' | 'Data Display & AI' | 'Charts Suite' | 'Composites & Shells';
  description: string;
  cliCommand: string;
  pubPackage: string;
  flutterImport: string;
  variants?: string[];
  sizes?: string[];
  slots?: ComponentSlot[];
  props: ComponentProp[];
  usageCode: string;
  previewType: string;
}

export const UI_CATEGORIES = [
  'Form Controls',
  'Layout & Structure',
  'Feedback & Overlays',
  'Data Display & AI',
  'Charts Suite',
  'Composites & Shells',
] as const;

export const UI_REGISTRY: UIComponentDoc[] = [
  // 1. FORM CONTROLS
  {
    slug: 'button',
    title: 'Button',
    name: 'BloomButton',
    category: 'Form Controls',
    description: 'Displays a button or a component that looks like a button with 8 sizing steps, soft destructive tint, and loading state indicators.',
    cliCommand: 'bloom ui add button',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    variants: ['defaultVariant', 'secondary', 'outline', 'ghost', 'destructive', 'link'],
    sizes: ['xs', 'sm', 'defaultSize', 'lg', 'iconXs', 'iconSm', 'icon', 'iconLg'],
    props: [
      { name: 'child', type: 'Widget', description: 'The button content label or icon widget.' },
      { name: 'onPressed', type: 'VoidCallback?', description: 'Callback invoked when button is tapped.' },
      { name: 'variant', type: 'BloomButtonVariant', defaultVal: 'defaultVariant', description: 'Visual style: default, secondary, outline, ghost, destructive, link.' },
      { name: 'size', type: 'BloomButtonSize', defaultVal: 'defaultSize', description: 'Dimension scale: xs (24px), sm (28px), default (32px), lg (36px).' },
      { name: 'loading', type: 'bool', defaultVal: 'false', description: 'Shows an inline loading spinner when true.' },
      { name: 'disabled', type: 'bool', defaultVal: 'false', description: 'Disables tap events and reduces opacity.' },
      { name: 'leading', type: 'Widget?', description: 'Optional leading icon.' },
      { name: 'trailing', type: 'Widget?', description: 'Optional trailing icon.' },
    ],
    usageCode: `BloomButton(
  variant: BloomButtonVariant.defaultVariant,
  size: BloomButtonSize.defaultSize,
  leading: const Icon(Icons.download, size: 16),
  onPressed: () {
    print('Deploying application...');
  },
  child: const Text('Deploy App'),
)`,
    previewType: 'button',
  },
  {
    slug: 'button-group',
    title: 'Button Group',
    name: 'BloomButtonGroup',
    category: 'Form Controls',
    description: 'A connected row of action buttons or toggle selectors with continuous border grouping.',
    cliCommand: 'bloom ui add button_group',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'items', type: 'List<BloomButtonGroupItem<T>>', description: 'List of button items in the group.' },
      { name: 'defaultValue', type: 'T?', description: 'Initial selected value.' },
      { name: 'onChanged', type: 'ValueChanged<T>?', description: 'Called when a segmented button is selected.' },
    ],
    slots: [
      { name: 'BloomButtonGroupItem', description: 'Individual item within the segmented group.' },
      { name: 'BloomButtonGroupSeparator', description: 'Vertical hairline separator between button items.' },
      { name: 'BloomButtonGroupText', description: 'Styled text block within a button group.' },
    ],
    usageCode: `BloomButtonGroup<String>(
  defaultValue: 'week',
  items: const [
    BloomButtonGroupItem(value: 'day', label: Text('Day')),
    BloomButtonGroupItem(value: 'week', label: Text('Week')),
    BloomButtonGroupItem(value: 'month', label: Text('Month')),
  ],
  onChanged: (selected) {
    print('Selected timeframe: \$selected');
  },
)`,
    previewType: 'button_group',
  },
  {
    slug: 'input',
    title: 'Input',
    name: 'BloomInput',
    category: 'Form Controls',
    description: 'Displays a 32px height calibrated form input field or a component that looks like an input field.',
    cliCommand: 'bloom ui add input',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'placeholder', type: 'String?', description: 'Hint placeholder text.' },
      { name: 'controller', type: 'TextEditingController?', description: 'Text editing controller.' },
      { name: 'obscureText', type: 'bool', defaultVal: 'false', description: 'Hides text for password inputs.' },
      { name: 'leading', type: 'Widget?', description: 'Leading icon or addon.' },
      { name: 'trailing', type: 'Widget?', description: 'Trailing icon or action button.' },
      { name: 'label', type: 'String?', description: 'Optional field label.' },
      { name: 'error', type: 'String?', description: 'Validation error text.' },
    ],
    usageCode: `BloomInput(
  placeholder: 'name@example.com',
  leading: const Icon(Icons.email_outlined, size: 16),
  keyboardType: TextInputType.emailAddress,
  onChanged: (val) {
    print('Email: \$val');
  },
)`,
    previewType: 'input',
  },
  {
    slug: 'input-group',
    title: 'Input Group',
    name: 'BloomInputGroup',
    category: 'Form Controls',
    description: 'Compose input fields with leading/trailing text addons, dropdown selects, and action buttons in a unified border container.',
    cliCommand: 'bloom ui add input_group',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    slots: [
      { name: 'BloomInputGroupAddon', description: 'Prefix or suffix addon container.' },
      { name: 'BloomInputGroupText', description: 'Muted prefix label like https:// or @.' },
      { name: 'BloomInputGroupButton', description: 'Connected action button attached to input edge.' },
    ],
    props: [
      { name: 'child', type: 'Widget', description: 'The inner BloomInput field.' },
      { name: 'addonLeading', type: 'Widget?', description: 'Left connected addon.' },
      { name: 'addonTrailing', type: 'Widget?', description: 'Right connected addon or button.' },
    ],
    usageCode: `BloomInputGroup(
  addonLeading: const BloomInputGroupText('https://'),
  addonTrailing: BloomInputGroupButton(
    child: const Icon(Icons.copy, size: 14),
    onPressed: () {},
  ),
  child: const BloomInput(placeholder: 'bloom.dev/username'),
)`,
    previewType: 'input_group',
  },
  {
    slug: 'input-otp',
    title: 'Input OTP',
    name: 'BloomInputOtp',
    category: 'Form Controls',
    description: 'Accessible one-time password / PIN entry with discrete animated slot boxes and separator styling.',
    cliCommand: 'bloom ui add input_otp',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'length', type: 'int', defaultVal: '6', description: 'Number of OTP digits.' },
      { name: 'onCompleted', type: 'ValueChanged<String>?', description: 'Called when all digits are filled.' },
      { name: 'onChanged', type: 'ValueChanged<String>?', description: 'Called on every digit change.' },
    ],
    usageCode: `BloomInputOtp(
  length: 6,
  onCompleted: (pin) {
    print('Verified PIN: \$pin');
  },
)`,
    previewType: 'input_otp',
  },
  {
    slug: 'textarea',
    title: 'Textarea',
    name: 'BloomTextarea',
    category: 'Form Controls',
    description: 'Multi-line expanded text input for paragraphs, descriptions, or code prompts.',
    cliCommand: 'bloom ui add textarea',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'minLines', type: 'int', defaultVal: '3', description: 'Minimum visible lines.' },
      { name: 'placeholder', type: 'String?', description: 'Placeholder hint text.' },
      { name: 'controller', type: 'TextEditingController?', description: 'Text editing controller.' },
    ],
    usageCode: `BloomTextarea(
  placeholder: 'Type your message or system instructions here...',
  minLines: 4,
  onChanged: (val) {},
)`,
    previewType: 'textarea',
  },
  {
    slug: 'checkbox',
    title: 'Checkbox',
    name: 'BloomCheckbox',
    category: 'Form Controls',
    description: 'A 16x16px control that allows the user to toggle between checked, unchecked, and indeterminate states.',
    cliCommand: 'bloom ui add checkbox',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'checked', type: 'bool?', description: 'Controlled checked state (null = indeterminate).' },
      { name: 'label', type: 'Widget?', description: 'Optional adjacent label text.' },
      { name: 'description', type: 'Widget?', description: 'Optional subtext description.' },
      { name: 'onChanged', type: 'ValueChanged<bool?>?', description: 'Callback when toggled.' },
    ],
    usageCode: `BloomCheckbox(
  checked: true,
  label: const Text('Accept terms and privacy policy'),
  description: const Text('You agree to our automated telemetry guidelines.'),
  onChanged: (val) {
    print('Checked: \$val');
  },
)`,
    previewType: 'checkbox',
  },
  {
    slug: 'radio',
    title: 'Radio Group',
    name: 'BloomRadioGroup',
    category: 'Form Controls',
    description: 'A set of 16px circular check buttons where only one button can be checked at a time.',
    cliCommand: 'bloom ui add radio',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'options', type: 'List<BloomRadioOption<T>>', description: 'List of radio options.' },
      { name: 'defaultValue', type: 'T?', description: 'Currently selected value.' },
      { name: 'onChanged', type: 'ValueChanged<T>?', description: 'Callback when selected option changes.' },
    ],
    usageCode: `BloomRadioGroup<String>(
  defaultValue: 'starter',
  options: const [
    BloomRadioOption(value: 'starter', label: Text('Starter Plan ($0/mo)')),
    BloomRadioOption(value: 'pro', label: Text('Pro Plan ($29/mo)')),
    BloomRadioOption(value: 'enterprise', label: Text('Enterprise (Custom)')),
  ],
  onChanged: (plan) {
    print('Selected plan: \$plan');
  },
)`,
    previewType: 'radio',
  },
  {
    slug: 'switch',
    title: 'Switch',
    name: 'BloomSwitch',
    category: 'Form Controls',
    description: 'A 32x18px control that allows the user to toggle between checked and unchecked states.',
    cliCommand: 'bloom ui add switch',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    sizes: ['sm (24x14px)', 'defaultSize (32x18px)'],
    props: [
      { name: 'checked', type: 'bool', description: 'Controlled on/off state.' },
      { name: 'size', type: 'BloomSwitchSize', defaultVal: 'defaultSize', description: 'Size step (sm or default).' },
      { name: 'label', type: 'Widget?', description: 'Adjacent label text.' },
      { name: 'onChanged', type: 'ValueChanged<bool>?', description: 'Callback when toggled.' },
    ],
    usageCode: `BloomSwitch(
  checked: true,
  label: const Text('Push Notifications'),
  onChanged: (enabled) {
    print('Notifications: \$enabled');
  },
)`,
    previewType: 'switch',
  },
  {
    slug: 'slider',
    title: 'Slider',
    name: 'BloomSlider',
    category: 'Form Controls',
    description: 'A 4px track slider with 12px white ring thumb for selecting values from a range.',
    cliCommand: 'bloom ui add slider',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'value', type: 'double', description: 'Current value (0.0 to 1.0).' },
      { name: 'onChanged', type: 'ValueChanged<double>?', description: 'Callback when sliding.' },
      { name: 'min', type: 'double', defaultVal: '0.0', description: 'Minimum slider bound.' },
      { name: 'max', type: 'double', defaultVal: '1.0', description: 'Maximum slider bound.' },
    ],
    usageCode: `BloomSlider(
  value: 0.75,
  min: 0.0,
  max: 1.0,
  onChanged: (v) {
    print('Volume: \$v');
  },
)`,
    previewType: 'slider',
  },
  {
    slug: 'select',
    title: 'Select',
    name: 'BloomSelect',
    category: 'Form Controls',
    description: 'Displays a 32px dropdown select picker matching shadcn base-nova styling.',
    cliCommand: 'bloom ui add select',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'value', type: 'T?', description: 'Currently selected value.' },
      { name: 'items', type: 'List<BloomSelectItem<T>>', description: 'Available select items.' },
      { name: 'onChanged', type: 'ValueChanged<T?>?', description: 'Callback when selection changes.' },
      { name: 'hintText', type: 'String?', description: 'Placeholder hint text.' },
    ],
    usageCode: `BloomSelect<String>(
  value: 'nova',
  items: const [
    BloomSelectItem(value: 'nova', label: 'Nova (Crisp Neutral)'),
    BloomSelectItem(value: 'vega', label: 'Vega (Warm Amber)'),
    BloomSelectItem(value: 'lyra', label: 'Lyra (Tech Violet)'),
  ],
  onChanged: (val) {
    print('Selected style: \$val');
  },
)`,
    previewType: 'select',
  },
  {
    slug: 'combobox',
    title: 'Combobox',
    name: 'BloomCombobox',
    category: 'Form Controls',
    description: 'Searchable autocomplete dropdown menu with multi-select tokenized chips support.',
    cliCommand: 'bloom ui add combobox',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'options', type: 'List<BloomComboboxOption<T>>', description: 'All filterable options.' },
      { name: 'onChanged', type: 'ValueChanged<T>?', description: 'Called when an option is chosen.' },
      { name: 'placeholder', type: 'String', defaultVal: "'Select option...'", description: 'Placeholder label.' },
    ],
    usageCode: `BloomCombobox<String>(
  placeholder: 'Select framework...',
  options: const [
    BloomComboboxOption(value: 'flutter', label: 'Flutter (Dart)'),
    BloomComboboxOption(value: 'nextjs', label: 'Next.js (React)'),
    BloomComboboxOption(value: 'astro', label: 'Astro (Web)'),
  ],
  onChanged: (val) {
    print('Selected: \$val');
  },
)`,
    previewType: 'combobox',
  },
  {
    slug: 'calendar',
    title: 'Calendar',
    name: 'BloomCalendar',
    category: 'Form Controls',
    description: 'A date picker calendar component supporting single, range, and multiple date selections.',
    cliCommand: 'bloom ui add calendar',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'mode', type: 'BloomCalendarMode', defaultVal: 'single', description: 'Selection mode: single or range.' },
      { name: 'initialDate', type: 'DateTime?', description: 'Initial selected date.' },
      { name: 'onDaySelected', type: 'ValueChanged<DateTime>?', description: 'Callback when day is tapped.' },
    ],
    usageCode: `BloomCalendar.single(
  initialDate: DateTime.now(),
  onDaySelected: (date) {
    print('Selected date: \$date');
  },
)`,
    previewType: 'calendar',
  },
  {
    slug: 'field',
    title: 'Field',
    name: 'BloomField',
    category: 'Form Controls',
    description: 'A complete composable form field wrapper providing FieldLabel, FieldDescription, and FieldError slots.',
    cliCommand: 'bloom ui add field',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    slots: [
      { name: 'BloomFieldGroup', description: 'Groups multiple adjacent fields.' },
      { name: 'BloomFieldLabel', description: 'Accessible label text with optional required marker.' },
      { name: 'BloomFieldDescription', description: 'Muted explanatory helper text.' },
      { name: 'BloomFieldError', description: 'Validation error text displayed below input.' },
    ],
    props: [
      { name: 'label', type: 'Widget?', description: 'Label slot.' },
      { name: 'child', type: 'Widget', description: 'Form input control widget.' },
      { name: 'description', type: 'Widget?', description: 'Helper description slot.' },
      { name: 'error', type: 'Widget?', description: 'Error message slot.' },
    ],
    usageCode: `BloomField(
  label: const BloomFieldLabel('Email Address', required: true),
  child: const BloomInput(placeholder: 'alex@example.com'),
  description: const BloomFieldDescription('We will never share your email.'),
)`,
    previewType: 'field',
  },

  // 2. LAYOUT & STRUCTURE
  {
    slug: 'card',
    title: 'Card',
    name: 'BloomCard',
    category: 'Layout & Structure',
    description: 'Displays a card with title, description, content, action header slots, and a shaded border-divided footer.',
    cliCommand: 'bloom ui add card',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    slots: [
      { name: 'BloomCardHeader', description: 'Top section with title, description, and action button.' },
      { name: 'BloomCardTitle', description: '16px bold title.' },
      { name: 'BloomCardDescription', description: 'Muted 13px subtitle.' },
      { name: 'BloomCardAction', description: 'Optional header action button placed in top right.' },
      { name: 'BloomCardContent', description: 'Main card body area.' },
      { name: 'BloomCardFooter', description: 'Shaded bottom bar with top divider border.' },
    ],
    props: [
      { name: 'header', type: 'Widget?', description: 'Card header slot.' },
      { name: 'content', type: 'Widget?', description: 'Main content slot.' },
      { name: 'footer', type: 'Widget?', description: 'Card footer slot.' },
    ],
    usageCode: `BloomCard(
  header: const BloomCardHeader(
    title: BloomCardTitle('Project Overview'),
    description: BloomCardDescription('Deployment metrics for production cluster.'),
  ),
  content: const Text('All services operating normally with 99.99% uptime.'),
  footer: BloomCardFooter(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        BloomButton(
          size: BloomButtonSize.sm,
          onPressed: () {},
          child: const Text('View Logs'),
        ),
      ],
    ),
  ),
)`,
    previewType: 'card',
  },
  {
    slug: 'accordion',
    title: 'Accordion',
    name: 'BloomAccordion',
    category: 'Layout & Structure',
    description: 'A vertically stacked set of interactive headings that each reveal a section of content.',
    cliCommand: 'bloom ui add accordion',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'items', type: 'List<BloomAccordionItem>', description: 'List of accordion panels.' },
    ],
    usageCode: `BloomAccordion(
  items: const [
    BloomAccordionItem(
      title: 'How do OTA updates work?',
      content: Text('Shorebird downloads Dart AOT patches in the background.'),
    ),
    BloomAccordionItem(
      title: 'Can I copy-paste components?',
      content: Text('Yes! Use the bloom ui CLI to copy source files directly.'),
    ),
  ],
)`,
    previewType: 'accordion',
  },
  {
    slug: 'tabs',
    title: 'Tabs',
    name: 'BloomTabs',
    category: 'Layout & Structure',
    description: 'A set of layered sections of content—known as tab panels—that are displayed one at a time. Supports pill and line underline variants.',
    cliCommand: 'bloom ui add tabs',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    variants: ['defaultVariant (pill)', 'line (underline)'],
    props: [
      { name: 'items', type: 'List<BloomTabItem<T>>', description: 'Tab headers and corresponding panel views.' },
      { name: 'defaultValue', type: 'T', description: 'Initial active tab key.' },
      { name: 'variant', type: 'TabsVariant', defaultVal: 'defaultVariant', description: 'Visual style: pill or line.' },
    ],
    usageCode: `BloomTabs<String>(
  defaultValue: 'overview',
  items: const [
    BloomTabItem(value: 'overview', label: Text('Overview'), content: Text('Overview panel')),
    BloomTabItem(value: 'analytics', label: Text('Analytics'), content: Text('Analytics charts')),
    BloomTabItem(value: 'settings', label: Text('Settings'), content: Text('Settings config')),
  ],
)`,
    previewType: 'tabs',
  },
  {
    slug: 'skeleton',
    title: 'Skeleton',
    name: 'BloomSkeleton',
    category: 'Layout & Structure',
    description: 'Used to show a placeholder while content is loading with a subtle pulse animation.',
    cliCommand: 'bloom ui add skeleton',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'width', type: 'double?', description: 'Skeleton width.' },
      { name: 'height', type: 'double?', description: 'Skeleton height.' },
      { name: 'borderRadius', type: 'BorderRadius?', description: 'Corner roundness.' },
    ],
    usageCode: `Row(
  children: const [
    BloomSkeleton(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
    SizedBox(width: 12),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BloomSkeleton(width: 140, height: 14),
        SizedBox(height: 6),
        BloomSkeleton(width: 80, height: 12),
      ],
    ),
  ],
)`,
    previewType: 'skeleton',
  },
  {
    slug: 'progress',
    title: 'Progress',
    name: 'BloomProgress',
    category: 'Layout & Structure',
    description: 'Displays a 4px height linear progress bar indicating completion of an operation.',
    cliCommand: 'bloom ui add progress',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'value', type: 'double', description: 'Progress percentage between 0.0 and 1.0.' },
      { name: 'color', type: 'Color?', description: 'Custom indicator color.' },
    ],
    usageCode: `BloomProgress(
  value: 0.68,
)`,
    previewType: 'progress',
  },

  // 3. FEEDBACK & OVERLAYS
  {
    slug: 'dialog',
    title: 'Dialog',
    name: 'BloomDialog',
    category: 'Feedback & Overlays',
    description: 'A modal window that appears in front of app content with shaded footer and compound title/description slots.',
    cliCommand: 'bloom ui add dialog',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    slots: [
      { name: 'BloomDialogHeader', description: 'Header container with title and description.' },
      { name: 'BloomDialogTitle', description: 'Bold dialog title.' },
      { name: 'BloomDialogDescription', description: 'Muted subtitle explanation.' },
      { name: 'BloomDialogContent', description: 'Main dialog body.' },
      { name: 'BloomDialogFooter', description: 'Shaded footer bar for action buttons.' },
    ],
    props: [
      { name: 'title', type: 'Widget?', description: 'Title slot widget.' },
      { name: 'description', type: 'Widget?', description: 'Description slot widget.' },
      { name: 'content', type: 'Widget?', description: 'Content body.' },
      { name: 'footer', type: 'Widget?', description: 'Action button row.' },
    ],
    usageCode: `BloomDialog.show(
  context: context,
  builder: (ctx) => BloomDialog(
    header: const BloomDialogHeader(
      title: BloomDialogTitle('Edit Profile'),
      description: BloomDialogDescription('Make changes to your account here.'),
    ),
    content: const BloomInput(placeholder: 'Display Name'),
    footer: BloomDialogFooter(
      child: BloomButton(
        size: BloomButtonSize.sm,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Save'),
      ),
    ),
  ),
)`,
    previewType: 'dialog',
  },
  {
    slug: 'alert-dialog',
    title: 'Alert Dialog',
    name: 'BloomAlertDialog',
    category: 'Feedback & Overlays',
    description: 'A modal dialog that interrupts the user with important content and expects a response.',
    cliCommand: 'bloom ui add alert_dialog',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'title', type: 'Widget', description: 'Warning title.' },
      { name: 'description', type: 'Widget', description: 'Detailed warning description.' },
      { name: 'cancel', type: 'Widget?', description: 'Cancel action button.' },
      { name: 'action', type: 'Widget', description: 'Confirm / destructive action button.' },
    ],
    usageCode: `BloomAlertDialog.show(
  context: context,
  title: const BloomDialogTitle('Delete Repository?'),
  description: const BloomDialogDescription('This action cannot be undone and will permanently erase all branches.'),
  cancel: BloomButton(
    variant: BloomButtonVariant.outline,
    size: BloomButtonSize.sm,
    onPressed: () => Navigator.pop(context),
    child: const Text('Cancel'),
  ),
  action: BloomButton(
    variant: BloomButtonVariant.destructive,
    size: BloomButtonSize.sm,
    onPressed: () {},
    child: const Text('Delete'),
  ),
)`,
    previewType: 'alert_dialog',
  },
  {
    slug: 'alert',
    title: 'Alert',
    name: 'BloomAlert',
    category: 'Feedback & Overlays',
    description: 'Displays a callout for user attention with 10x8px padding and soft status tints.',
    cliCommand: 'bloom ui add alert',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    variants: ['defaultVariant', 'destructive', 'success', 'warning', 'info'],
    slots: [
      { name: 'BloomAlertTitle', description: 'Alert headline text.' },
      { name: 'BloomAlertDescription', description: 'Detailed explanatory copy.' },
      { name: 'BloomAlertAction', description: 'Optional trailing action button.' },
    ],
    props: [
      { name: 'title', type: 'Widget?', description: 'Title slot.' },
      { name: 'description', type: 'Widget?', description: 'Description body.' },
      { name: 'variant', type: 'BloomAlertVariant', defaultVal: 'defaultVariant', description: 'Status color style.' },
      { name: 'icon', type: 'Widget?', description: 'Optional status icon.' },
    ],
    usageCode: `BloomAlert(
  variant: BloomAlertVariant.info,
  icon: const Icon(Icons.info_outline, size: 16),
  title: const BloomAlertTitle('Heads Up!'),
  description: const BloomAlertDescription('You can add components to your app using the bloom CLI.'),
)`,
    previewType: 'alert',
  },
  {
    slug: 'sheet',
    title: 'Sheet',
    name: 'BloomSheet',
    category: 'Feedback & Overlays',
    description: 'Extends the Dialog component to display 4-directional slide-over drawers (left, right, top, bottom).',
    cliCommand: 'bloom ui add sheet',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    variants: ['top', 'bottom', 'left', 'right'],
    props: [
      { name: 'side', type: 'BloomSheetSide', defaultVal: 'right', description: 'Slide edge direction.' },
      { name: 'header', type: 'Widget?', description: 'Sheet header.' },
      { name: 'child', type: 'Widget', description: 'Body content.' },
      { name: 'footer', type: 'Widget?', description: 'Sheet footer action row.' },
    ],
    usageCode: `BloomSheet.show(
  context: context,
  side: BloomSheetSide.right,
  builder: (ctx) => BloomSheet(
    side: BloomSheetSide.right,
    header: const BloomSheetHeader(
      title: BloomSheetTitle('Navigation'),
    ),
    child: const Text('Sheet content'),
  ),
)`,
    previewType: 'sheet',
  },
  {
    slug: 'drawer',
    title: 'Drawer',
    name: 'BloomDrawer',
    category: 'Feedback & Overlays',
    description: 'A swipeable gesture bottom sheet with drag handle and spring snap points.',
    cliCommand: 'bloom ui add drawer',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'header', type: 'Widget?', description: 'Drawer top section.' },
      { name: 'child', type: 'Widget', description: 'Scrollable sheet content.' },
      { name: 'footer', type: 'Widget?', description: 'Bottom actions.' },
    ],
    usageCode: `BloomDrawer.show(
  context: context,
  builder: (ctx) => BloomDrawer(
    header: const BloomDrawerHeader(
      title: BloomDrawerTitle('Quick Actions'),
    ),
    child: const Text('Drawer options'),
  ),
)`,
    previewType: 'drawer',
  },
  {
    slug: 'sonner',
    title: 'Sonner / Toast',
    name: 'BloomSonner',
    category: 'Feedback & Overlays',
    description: 'An opinionated toast notification system with success, error, warning, and loading status styles.',
    cliCommand: 'bloom ui add sonner',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'message', type: 'String', description: 'Toast text message.' },
      { name: 'action', type: 'Widget?', description: 'Optional action button.' },
    ],
    usageCode: `BloomSonner.success(context, 'Release deployed to 12,400 active devices!');
BloomSonner.error(context, 'Build compilation failed. Check logs.');`,
    previewType: 'sonner',
  },
  {
    slug: 'dropdown-menu',
    title: 'Dropdown Menu',
    name: 'BloomDropdownMenu',
    category: 'Feedback & Overlays',
    description: 'Displays a menu to the user—such as a set of actions or functions—triggered by a button.',
    cliCommand: 'bloom ui add dropdown_menu',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'trigger', type: 'Widget', description: 'Button that opens the menu.' },
      { name: 'items', type: 'List<BloomDropdownMenuItem>', description: 'List of menu items.' },
    ],
    usageCode: `BloomDropdownMenu(
  trigger: BloomButton(
    variant: BloomButtonVariant.outline,
    size: BloomButtonSize.sm,
    child: const Text('Options'),
  ),
  items: [
    BloomDropdownMenuItem(
      label: 'Profile',
      icon: const Icon(Icons.person, size: 16),
      onTap: () {},
    ),
    BloomDropdownMenuItem(
      label: 'Delete Account',
      isDestructive: true,
      icon: const Icon(Icons.delete, size: 16),
      onTap: () {},
    ),
  ],
)`,
    previewType: 'dropdown_menu',
  },

  // 4. DATA DISPLAY & AI
  {
    slug: 'avatar',
    title: 'Avatar',
    name: 'BloomAvatar',
    category: 'Data Display & AI',
    description: 'An image element with a fallback monogram for representing the user with 24/32/40px sizes and AvatarGroup.',
    cliCommand: 'bloom ui add avatar',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    sizes: ['sm (24px)', 'defaultSize (32px)', 'lg (40px)'],
    props: [
      { name: 'image', type: 'ImageProvider?', description: 'User image source (e.g. NetworkImage from Unsplash or AssetImage).' },
      { name: 'name', type: 'String?', description: 'Fallback name used to generate monogram initials (e.g. "Sophia Davis").' },
      { name: 'size', type: 'BloomAvatarSize', defaultVal: 'defaultSize', description: 'Size step: sm (24px), defaultSize (32px), lg (40px).' },
      { name: 'badge', type: 'Widget?', description: 'Optional status indicator badge (e.g. online presence dot).' },
    ],
    usageCode: `BloomAvatar(
  image: const NetworkImage(
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&h=120&q=80',
  ),
  name: 'Sophia Davis',
  size: BloomAvatarSize.lg,
  badge: const BloomAvatarBadge(
    color: Colors.green,
  ),
)`,
    previewType: 'avatar',
  },
  {
    slug: 'badge',
    title: 'Badge & Chip',
    name: 'BloomBadge',
    category: 'Data Display & AI',
    description: 'Displays a 20px pill badge or interactive BloomChip with soft destructive and status tints.',
    cliCommand: 'bloom ui add badge',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    variants: ['defaultVariant', 'secondary', 'destructive', 'outline', 'success', 'warning', 'info'],
    props: [
      { name: 'child', type: 'Widget', description: 'Badge label content.' },
      { name: 'variant', type: 'BloomBadgeVariant', defaultVal: 'defaultVariant', description: 'Status color style.' },
    ],
    usageCode: `BloomBadge(
  variant: BloomBadgeVariant.success,
  child: const Text('ONLINE'),
)`,
    previewType: 'badge',
  },
  {
    slug: 'kbd',
    title: 'Kbd',
    name: 'BloomKbd',
    category: 'Data Display & AI',
    description: 'A 20px height sans-serif keyboard shortcut token matching shadcn base-nova specifications.',
    cliCommand: 'bloom ui add kbd',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'text', type: 'String', description: 'Shortcut key symbol (e.g. ⌘K, Ctrl+P, Esc).' },
    ],
    usageCode: `Row(
  children: const [
    Text('Open command menu'),
    SizedBox(width: 8),
    BloomKbd(text: '⌘K'),
  ],
)`,
    previewType: 'kbd',
  },
  {
    slug: 'table',
    title: 'Table & Data Table',
    name: 'BloomTable',
    category: 'Data Display & AI',
    description: 'A responsive data table container with 40px headers, cell alignment, and sortable columns.',
    cliCommand: 'bloom ui add table',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    slots: [
      { name: 'BloomTableHead', description: '40px header column cell.' },
      { name: 'BloomTableCell', description: 'Table body row cell.' },
    ],
    props: [
      { name: 'rows', type: 'List<TableRow>?', description: 'Structured rows.' },
    ],
    usageCode: `BloomTable(
  rows: [
    TableRow(
      children: const [
        BloomTableHead(child: Text('Invoice')),
        BloomTableHead(child: Text('Status')),
        BloomTableHead(child: Text('Amount')),
      ],
    ),
    TableRow(
      children: const [
        BloomTableCell(child: Text('INV001')),
        BloomTableCell(child: Text('Paid')),
        BloomTableCell(child: Text('$250.00')),
      ],
    ),
  ],
)`,
    previewType: 'table',
  },
  {
    slug: 'sidebar',
    title: 'Sidebar',
    name: 'BloomSidebar',
    category: 'Data Display & AI',
    description: 'A composable, collapsible navigation sidebar system matching shadcn base-nova with groups, headers, and footer slots.',
    cliCommand: 'bloom ui add sidebar',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    slots: [
      { name: 'BloomSidebarHeader', description: '48px header container with app logo.' },
      { name: 'BloomSidebarContent', description: 'Scrollable middle menu list.' },
      { name: 'BloomSidebarGroup', description: 'Grouped section with uppercase header title.' },
      { name: 'BloomSidebarMenuButton', description: '32px interactive item button with hover and active state.' },
      { name: 'BloomSidebarFooter', description: 'Bottom user profile or settings tile.' },
    ],
    props: [
      { name: 'header', type: 'Widget?', description: 'Sidebar header slot.' },
      { name: 'content', type: 'Widget?', description: 'Sidebar body content.' },
      { name: 'footer', type: 'Widget?', description: 'Sidebar footer slot.' },
    ],
    usageCode: `BloomSidebar(
  header: const BloomSidebarHeader(child: Text('Bloom App')),
  content: BloomSidebarGroup(
    label: 'Platform',
    children: [
      BloomSidebarMenuButton(
        icon: const Icon(Icons.dashboard),
        label: const Text('Overview'),
        isCurrent: true,
      ),
      BloomSidebarMenuButton(
        icon: const Icon(Icons.cloud_upload),
        label: const Text('OTA Releases'),
      ),
    ],
  ),
)`,
    previewType: 'sidebar',
  },

  // 5. CHARTS SUITE
  {
    slug: 'chart',
    title: 'Charts Suite',
    name: 'BloomChart',
    category: 'Charts Suite',
    description: 'Pure Dart token-driven chart suite supporting Area, Bar, Line, Pie, Radar, and Radial charts with responsive drag tracking.',
    cliCommand: 'bloom ui add chart',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    variants: ['area', 'bar', 'line', 'pie', 'radar', 'radial'],
    props: [
      { name: 'type', type: 'BloomChartType', defaultVal: 'bar', description: 'Chart visualization mode.' },
      { name: 'data', type: 'BloomChartData', description: 'Labels and data series.' },
      { name: 'height', type: 'double?', defaultVal: '240', description: 'Chart canvas height.' },
      { name: 'showLegend', type: 'bool', defaultVal: 'true', description: 'Display series legend.' },
    ],
    usageCode: `BloomChart(
  type: BloomChartType.area,
  height: 220,
  data: const BloomChartData(
    labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
    series: [
      BloomChartSeries(
        name: 'Desktop',
        values: [186, 305, 237, 73, 209, 214],
        color: BloomColors.petalBlue,
      ),
      BloomChartSeries(
        name: 'Mobile',
        values: [80, 200, 120, 190, 130, 140],
        color: BloomColors.petalPink,
      ),
    ],
  ),
)`,
    previewType: 'chart',
  },

  // 6. COMPOSITES & SHELLS
  {
    slug: 'command-palette',
    title: 'Command Palette',
    name: 'BloomCommandPalette',
    category: 'Composites & Shells',
    description: 'Fast, accessible command menu for searching actions, files, and navigation shortcuts.',
    cliCommand: 'bloom ui add command_palette',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'items', type: 'List<BloomCommandItem>', description: 'List of searchable actions.' },
    ],
    usageCode: `BloomCommandPalette(
  items: [
    BloomCommandItem(
      title: 'Deploy to Production',
      shortcut: '⌘P',
      onSelected: () {},
    ),
    BloomCommandItem(
      title: 'Open Settings',
      shortcut: '⌘,',
      onSelected: () {},
    ),
  ],
)`,
    previewType: 'command_palette',
  },
  {
    slug: 'app-shell',
    title: 'App & Dashboard Shell',
    name: 'BloomDashboardShell',
    category: 'Composites & Shells',
    description: 'Production responsive application frame combining top bar, collapsible sidebar, and responsive mobile nav.',
    cliCommand: 'bloom ui add app_shell',
    pubPackage: 'bloom_ui',
    flutterImport: "import 'package:bloom_ui/bloom_ui.dart';",
    props: [
      { name: 'selectedIndex', type: 'int', description: 'Active destination index.' },
      { name: 'navigationItems', type: 'List<BloomNavigationItem>', description: 'Destination items.' },
      { name: 'body', type: 'Widget', description: 'Main screen content.' },
    ],
    usageCode: `BloomDashboardShell(
  selectedIndex: 0,
  onDestinationSelected: (i) {},
  navigationItems: const [
    BloomNavigationItem(icon: Icon(Icons.home), label: Text('Home')),
    BloomNavigationItem(icon: Icon(Icons.analytics), label: Text('Analytics')),
    BloomNavigationItem(icon: Icon(Icons.settings), label: Text('Settings')),
  ],
  body: const Center(child: Text('Dashboard View')),
)`,
    previewType: 'app_shell',
  },
];
