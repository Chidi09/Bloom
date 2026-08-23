// lib/src/a11y.dart
//
// Pure-Dart Accessibility & WAI-ARIA module for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting.

import 'package:signals/signals.dart';
import 'framework.dart';

// ─── ARIA Enums ─────────────────────────────────────────────────────────────

/// WAI-ARIA landmark, widget, and structure roles.
///
/// Use with [aria] or [BloomAriaAttributesExtension.withAria] to assign semantic
/// roles to elements.
///
/// ```dart
/// Div(
///   attrs: aria(role: AriaRole.navigation, label: 'Main menu'),
///   children: [...],
/// )
/// ```
enum AriaRole {
  // Landmark roles
  banner('banner'),
  complementary('complementary'),
  contentinfo('contentinfo'),
  form('form'),
  main('main'),
  navigation('navigation'),
  region('region'),
  search('search'),

  // Widget roles
  alert('alert'),
  alertdialog('alertdialog'),
  button('button'),
  checkbox('checkbox'),
  combobox('combobox'),
  dialog('dialog'),
  gridcell('gridcell'),
  link('link'),
  listbox('listbox'),
  log('log'),
  marquee('marquee'),
  menu('menu'),
  menubar('menubar'),
  menuitem('menuitem'),
  menuitemcheckbox('menuitemcheckbox'),
  menuitemradio('menuitemradio'),
  option('option'),
  progressbar('progressbar'),
  radio('radio'),
  radiogroup('radiogroup'),
  scrollbar('scrollbar'),
  searchbox('searchbox'),
  separator('separator'),
  slider('slider'),
  spinbutton('spinbutton'),
  status('status'),
  switchRole('switch'),
  tab('tab'),
  tablist('tablist'),
  tabpanel('tabpanel'),
  textbox('textbox'),
  timer('timer'),
  tooltip('tooltip'),
  tree('tree'),
  treegrid('treegrid'),
  treeitem('treeitem'),

  // Document structure & Composite roles
  application('application'),
  article('article'),
  cell('cell'),
  columnheader('columnheader'),
  definition('definition'),
  directory('directory'),
  document('document'),
  feed('feed'),
  figure('figure'),
  grid('grid'),
  group('group'),
  heading('heading'),
  img('img'),
  list('list'),
  listitem('listitem'),
  math('math'),
  meter('meter'),
  none('none'),
  note('note'),
  presentation('presentation'),
  row('row'),
  rowgroup('rowgroup'),
  rowheader('rowheader'),
  table('table'),
  term('term'),
  toolbar('toolbar');

  /// The raw WAI-ARIA role attribute string.
  final String value;

  const AriaRole(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-live`.
///
/// Controls how screen readers announce dynamic updates to a live region.
///
/// ```dart
/// Div(
///   attrs: aria(live: AriaLive.polite, atomic: true),
///   text: 'Status updated',
/// )
/// ```
enum AriaLive {
  /// Updates are not announced automatically.
  off('off'),

  /// Updates are announced at the next graceful opportunity (user is idle).
  polite('polite'),

  /// Updates interrupt the user immediately.
  assertive('assertive');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaLive(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-current`.
///
/// Indicates the element that represents the current item within a container or set.
///
/// ```dart
/// Nav(
///   children: [
///     A(href: '/home', attrs: aria(current: AriaCurrent.page), text: 'Home'),
///   ],
/// )
/// ```
enum AriaCurrent {
  page('page'),
  step('step'),
  location('location'),
  date('date'),
  time('time'),
  trueValue('true'),
  falseValue('false');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaCurrent(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-haspopup`.
///
/// Indicates the availability and type of interactive popup element.
///
/// ```dart
/// Button(
///   attrs: aria(hasPopup: AriaHasPopup.menu, expanded: false),
///   text: 'Options',
/// )
/// ```
enum AriaHasPopup {
  falseValue('false'),
  trueValue('true'),
  menu('menu'),
  listbox('listbox'),
  tree('tree'),
  grid('grid'),
  dialog('dialog');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaHasPopup(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-pressed`.
///
/// Indicates the current "pressed" state of a toggle button.
///
/// ```dart
/// Button(
///   attrs: aria(pressedState: AriaPressed.mixed),
///   text: 'Mute All',
/// )
/// ```
enum AriaPressed {
  trueValue('true'),
  falseValue('false'),
  mixed('mixed');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaPressed(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-checked`.
///
/// Indicates the current "checked" state of checkboxes, radio buttons, and other widgets.
///
/// ```dart
/// Div(
///   attrs: aria(role: AriaRole.checkbox, checkedState: AriaChecked.mixed),
///   text: 'Select All',
/// )
/// ```
enum AriaChecked {
  trueValue('true'),
  falseValue('false'),
  mixed('mixed');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaChecked(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-invalid`.
///
/// Indicates that the entered value does not conform to the expected format.
///
/// ```dart
/// Input(
///   attrs: aria(invalidState: AriaInvalid.spelling),
/// )
/// ```
enum AriaInvalid {
  trueValue('true'),
  falseValue('false'),
  grammar('grammar'),
  spelling('spelling');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaInvalid(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-orientation`.
///
/// Defines whether an element's orientation is horizontal, vertical, or unknown/ambiguous.
///
/// ```dart
/// Div(
///   attrs: aria(role: AriaRole.scrollbar, orientation: AriaOrientation.vertical),
/// )
/// ```
enum AriaOrientation {
  horizontal('horizontal'),
  vertical('vertical'),
  undefined('undefined');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaOrientation(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-autocomplete`.
///
/// Indicates whether inputting text could trigger display of predictions.
///
/// ```dart
/// Input(
///   attrs: aria(autocomplete: AriaAutocomplete.list),
/// )
/// ```
enum AriaAutocomplete {
  inline('inline'),
  list('list'),
  both('both'),
  none('none');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaAutocomplete(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-sort`.
///
/// Indicates if items in a table or grid are sorted in ascending or descending order.
///
/// ```dart
/// Th(
///   attrs: aria(sort: AriaSort.ascending),
///   text: 'Name',
/// )
/// ```
enum AriaSort {
  ascending('ascending'),
  descending('descending'),
  none('none'),
  other('other');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaSort(this.value);

  @override
  String toString() => value;
}

/// Allowed values for `aria-relevant`.
///
/// Indicates what notifications the user agent will trigger when the accessibility
/// tree within a live region is modified.
///
/// ```dart
/// Div(
///   attrs: aria(live: AriaLive.polite, relevant: AriaRelevant.additionsText),
/// )
/// ```
enum AriaRelevant {
  additions('additions'),
  removals('removals'),
  text('text'),
  all('all'),
  additionsText('additions text');

  /// The raw WAI-ARIA attribute string value.
  final String value;

  const AriaRelevant(this.value);

  @override
  String toString() => value;
}

// ─── ARIA Attribute Builder & Helpers ───────────────────────────────────────

String _formatNum(num n) {
  if (n is int || n == n.roundToDouble()) {
    return n.toInt().toString();
  }
  return n.toString();
}

/// Generates a map of WAI-ARIA and accessibility attributes.
///
/// Only non-null parameters are included in the returned map.
/// Boolean parameters are serialized as `"true"` or `"false"`.
///
/// Compose directly with element `attrs`:
///
/// ```dart
/// Button(
///   attrs: {
///     ...aria(
///       role: AriaRole.button,
///       label: 'Close dialog',
///       expanded: false,
///       controls: 'settings-modal',
///     ),
///     'id': 'close-btn',
///   },
///   text: 'Close',
/// )
/// ```
Map<String, String> aria({
  AriaRole? role,
  String? label,
  String? labelledBy,
  String? labelledby,
  String? describedBy,
  String? describedby,
  String? details,
  String? errorMessage,
  String? errormessage,
  String? flowTo,
  String? flowto,
  String? controls,
  String? owns,
  bool? hidden,
  bool? expanded,
  bool? selected,
  bool? checked,
  AriaChecked? checkedState,
  bool? pressed,
  AriaPressed? pressedState,
  bool? disabled,
  bool? required,
  bool? readOnly,
  bool? readonly,
  bool? modal,
  bool? multiselectable,
  bool? multiLine,
  bool? multiline,
  bool? busy,
  bool? atomic,
  bool? invalid,
  AriaInvalid? invalidState,
  AriaLive? live,
  AriaCurrent? current,
  AriaHasPopup? hasPopup,
  AriaHasPopup? haspopup,
  AriaOrientation? orientation,
  AriaAutocomplete? autocomplete,
  AriaSort? sort,
  AriaRelevant? relevant,
  int? level,
  int? setSize,
  int? setsize,
  int? posInSet,
  int? posinset,
  int? colIndex,
  int? rowIndex,
  int? colSpan,
  int? rowSpan,
  num? valueMin,
  num? valuemin,
  num? valueMax,
  num? valuemax,
  num? valueNow,
  num? valuenow,
  String? valueText,
  String? valuetext,
  String? keyShortcuts,
  String? keyshortcuts,
  String? placeholder,
  String? roleDescription,
  String? roledescription,
  Map<String, String>? extra,
}) {
  final out = <String, String>{};

  if (role != null) out['role'] = role.value;
  if (label != null) out['aria-label'] = label;

  final effLabelledBy = labelledBy ?? labelledby;
  if (effLabelledBy != null) out['aria-labelledby'] = effLabelledBy;

  final effDescribedBy = describedBy ?? describedby;
  if (effDescribedBy != null) out['aria-describedby'] = effDescribedBy;

  if (details != null) out['aria-details'] = details;

  final effErrorMessage = errorMessage ?? errormessage;
  if (effErrorMessage != null) out['aria-errormessage'] = effErrorMessage;

  final effFlowTo = flowTo ?? flowto;
  if (effFlowTo != null) out['aria-flowto'] = effFlowTo;

  if (controls != null) out['aria-controls'] = controls;
  if (owns != null) out['aria-owns'] = owns;

  if (hidden != null) out['aria-hidden'] = hidden ? 'true' : 'false';
  if (expanded != null) out['aria-expanded'] = expanded ? 'true' : 'false';
  if (selected != null) out['aria-selected'] = selected ? 'true' : 'false';

  final effChecked = checkedState?.value ?? (checked != null ? (checked ? 'true' : 'false') : null);
  if (effChecked != null) out['aria-checked'] = effChecked;

  final effPressed = pressedState?.value ?? (pressed != null ? (pressed ? 'true' : 'false') : null);
  if (effPressed != null) out['aria-pressed'] = effPressed;

  if (disabled != null) out['aria-disabled'] = disabled ? 'true' : 'false';
  if (required != null) out['aria-required'] = required ? 'true' : 'false';

  final effReadOnly = readOnly ?? readonly;
  if (effReadOnly != null) out['aria-readonly'] = effReadOnly ? 'true' : 'false';

  if (modal != null) out['aria-modal'] = modal ? 'true' : 'false';
  if (multiselectable != null) {
    out['aria-multiselectable'] = multiselectable ? 'true' : 'false';
  }

  final effMultiLine = multiLine ?? multiline;
  if (effMultiLine != null) {
    out['aria-multiline'] = effMultiLine ? 'true' : 'false';
  }

  if (busy != null) out['aria-busy'] = busy ? 'true' : 'false';
  if (atomic != null) out['aria-atomic'] = atomic ? 'true' : 'false';

  final effInvalid = invalidState?.value ?? (invalid != null ? (invalid ? 'true' : 'false') : null);
  if (effInvalid != null) out['aria-invalid'] = effInvalid;

  if (live != null) out['aria-live'] = live.value;
  if (current != null) out['aria-current'] = current.value;

  final effHasPopup = hasPopup ?? haspopup;
  if (effHasPopup != null) out['aria-haspopup'] = effHasPopup.value;

  if (orientation != null) out['aria-orientation'] = orientation.value;
  if (autocomplete != null) out['aria-autocomplete'] = autocomplete.value;
  if (sort != null) out['aria-sort'] = sort.value;
  if (relevant != null) out['aria-relevant'] = relevant.value;

  if (level != null) out['aria-level'] = level.toString();

  final effSetSize = setSize ?? setsize;
  if (effSetSize != null) out['aria-setsize'] = effSetSize.toString();

  final effPosInSet = posInSet ?? posinset;
  if (effPosInSet != null) out['aria-posinset'] = effPosInSet.toString();

  if (colIndex != null) out['aria-colindex'] = colIndex.toString();
  if (rowIndex != null) out['aria-rowindex'] = rowIndex.toString();
  if (colSpan != null) out['aria-colspan'] = colSpan.toString();
  if (rowSpan != null) out['aria-rowspan'] = rowSpan.toString();

  final effValueMin = valueMin ?? valuemin;
  if (effValueMin != null) out['aria-valuemin'] = _formatNum(effValueMin);

  final effValueMax = valueMax ?? valuemax;
  if (effValueMax != null) out['aria-valuemax'] = _formatNum(effValueMax);

  final effValueNow = valueNow ?? valuenow;
  if (effValueNow != null) out['aria-valuenow'] = _formatNum(effValueNow);

  final effValueText = valueText ?? valuetext;
  if (effValueText != null) out['aria-valuetext'] = effValueText;

  final effKeyShortcuts = keyShortcuts ?? keyshortcuts;
  if (effKeyShortcuts != null) out['aria-keyshortcuts'] = effKeyShortcuts;

  if (placeholder != null) out['aria-placeholder'] = placeholder;

  final effRoleDescription = roleDescription ?? roledescription;
  if (effRoleDescription != null) {
    out['aria-roledescription'] = effRoleDescription;
  }

  if (extra != null) {
    out.addAll(extra);
  }

  return out;
}

/// Helper for constructing a single ARIA attribute map entry.
///
/// Automatically prefixes [name] with `aria-` if not already present.
///
/// ```dart
/// Div(
///   attrs: {
///     ...ariaAttr('modal', 'true'),
///   },
/// )
/// ```
Map<String, String> ariaAttr(String name, String value) {
  final key = name.startsWith('aria-') ? name : 'aria-$name';
  return {key: value};
}

/// Extension on [Map<String, String>] to ergonomically chain and merge ARIA attributes.
///
/// ```dart
/// Div(
///   attrs: {'id': 'primary-tab'}.withAria(
///     role: AriaRole.tab,
///     selected: true,
///     controls: 'tabpanel-1',
///   ),
/// )
/// ```
extension BloomAriaAttributesExtension on Map<String, String>? {
  /// Merges ARIA attributes into this map without mutating the original map.
  Map<String, String> withAria({
    AriaRole? role,
    String? label,
    String? labelledBy,
    String? labelledby,
    String? describedBy,
    String? describedby,
    String? details,
    String? errorMessage,
    String? errormessage,
    String? flowTo,
    String? flowto,
    String? controls,
    String? owns,
    bool? hidden,
    bool? expanded,
    bool? selected,
    bool? checked,
    AriaChecked? checkedState,
    bool? pressed,
    AriaPressed? pressedState,
    bool? disabled,
    bool? required,
    bool? readOnly,
    bool? readonly,
    bool? modal,
    bool? multiselectable,
    bool? multiLine,
    bool? multiline,
    bool? busy,
    bool? atomic,
    bool? invalid,
    AriaInvalid? invalidState,
    AriaLive? live,
    AriaCurrent? current,
    AriaHasPopup? hasPopup,
    AriaHasPopup? haspopup,
    AriaOrientation? orientation,
    AriaAutocomplete? autocomplete,
    AriaSort? sort,
    AriaRelevant? relevant,
    int? level,
    int? setSize,
    int? setsize,
    int? posInSet,
    int? posinset,
    int? colIndex,
    int? rowIndex,
    int? colSpan,
    int? rowSpan,
    num? valueMin,
    num? valuemin,
    num? valueMax,
    num? valuemax,
    num? valueNow,
    num? valuenow,
    String? valueText,
    String? valuetext,
    String? keyShortcuts,
    String? keyshortcuts,
    String? placeholder,
    String? roleDescription,
    String? roledescription,
    Map<String, String>? extra,
  }) {
    final ariaMap = aria(
      role: role,
      label: label,
      labelledBy: labelledBy,
      labelledby: labelledby,
      describedBy: describedBy,
      describedby: describedby,
      details: details,
      errorMessage: errorMessage,
      errormessage: errormessage,
      flowTo: flowTo,
      flowto: flowto,
      controls: controls,
      owns: owns,
      hidden: hidden,
      expanded: expanded,
      selected: selected,
      checked: checked,
      checkedState: checkedState,
      pressed: pressed,
      pressedState: pressedState,
      disabled: disabled,
      required: required,
      readOnly: readOnly,
      readonly: readonly,
      modal: modal,
      multiselectable: multiselectable,
      multiLine: multiLine,
      multiline: multiline,
      busy: busy,
      atomic: atomic,
      invalid: invalid,
      invalidState: invalidState,
      live: live,
      current: current,
      hasPopup: hasPopup,
      haspopup: haspopup,
      orientation: orientation,
      autocomplete: autocomplete,
      sort: sort,
      relevant: relevant,
      level: level,
      setSize: setSize,
      setsize: setsize,
      posInSet: posInSet,
      posinset: posinset,
      colIndex: colIndex,
      rowIndex: rowIndex,
      colSpan: colSpan,
      rowSpan: rowSpan,
      valueMin: valueMin,
      valuemin: valuemin,
      valueMax: valueMax,
      valuemax: valuemax,
      valueNow: valueNow,
      valuenow: valuenow,
      valueText: valueText,
      valuetext: valuetext,
      keyShortcuts: keyShortcuts,
      keyshortcuts: keyshortcuts,
      placeholder: placeholder,
      roleDescription: roleDescription,
      roledescription: roledescription,
      extra: extra,
    );

    if (this == null || this!.isEmpty) return ariaMap;
    return {...this!, ...ariaMap};
  }
}

// ─── Screen-Reader Only / Visually-Hidden ───────────────────────────────────

/// Standard CSS class name for visually-hidden screen-reader elements.
const String visuallyHiddenClass = 'bloom-sr-only';

/// Standard alias CSS class name for screen-reader elements (`sr-only`).
const String srOnlyClass = 'sr-only';

/// Standard inline CSS rule implementing the clip-rect technique.
const String visuallyHiddenStyle =
    'position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; '
    'overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;';

/// Complete CSS stylesheet rules for `bloom-sr-only` and `sr-only` classes.
const String visuallyHiddenCss =
    '.$visuallyHiddenClass, .$srOnlyClass {'
    ' position: absolute !important;'
    ' width: 1px !important;'
    ' height: 1px !important;'
    ' padding: 0 !important;'
    ' margin: -1px !important;'
    ' overflow: hidden !important;'
    ' clip: rect(0, 0, 0, 0) !important;'
    ' white-space: nowrap !important;'
    ' border: 0 !important;'
    '}';

/// Emits a `<style>` block declaring the `.bloom-sr-only` and `.sr-only` CSS utility classes.
///
/// ```dart
/// Head(
///   children: [
///     visuallyHiddenStyleNode(),
///   ],
/// )
/// ```
StyleNode visuallyHiddenStyleNode() => StyleNode(visuallyHiddenCss);

/// Style descriptor for embedding screen-reader utility CSS rules.
///
/// ```dart
/// Div(
///   children: [
///     const VisuallyHiddenStyle(),
///     // ...
///   ],
/// )
/// ```
class VisuallyHiddenStyle extends StyleNode {
  const VisuallyHiddenStyle() : super(visuallyHiddenCss);
}

/// Renders a `<span>` element visually hidden from sighted users but fully
/// accessible to screen readers and assistive technologies.
///
/// Uses the battle-tested clip-rect CSS technique.
///
/// ```dart
/// Button(
///   children: [
///     Icon('trash'),
///     VisuallyHidden(text: 'Delete record'),
///   ],
/// )
/// ```
class VisuallyHidden extends Span {
  VisuallyHidden({
    super.text,
    String? className,
    String? style,
    super.attrs,
    super.children = const [],
    super.onClick,
    super.onDblClick,
    super.onMouseEnter,
    super.onMouseLeave,
  }) : super(
          className: cx([visuallyHiddenClass, className]),
          style: style != null ? '$visuallyHiddenStyle $style' : visuallyHiddenStyle,
        );

  const VisuallyHidden.raw({
    super.text,
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
  }) : super.raw();
}

// ─── Live Region & Announcer ────────────────────────────────────────────────

/// Pure-Dart reactive state controller for broadcasting live screen-reader announcements.
///
/// Maintains reactive signals for polite and assertive announcement channels.
///
/// ```dart
/// // Dispatch an announcement from anywhere in your app:
/// BloomAnnouncer.instance.announce('Route changed to Settings');
/// ```
class BloomAnnouncer {
  /// Reactive signal containing the latest polite announcement text.
  final Signal<String> politeMessage = signal('');

  /// Reactive signal containing the latest assertive announcement text.
  final Signal<String> assertiveMessage = signal('');

  /// Global singleton instance of [BloomAnnouncer].
  static final BloomAnnouncer instance = BloomAnnouncer();

  /// Announces [message] to screen readers.
  ///
  /// Defaults to [AriaLive.polite].
  void announce(String message, {AriaLive mode = AriaLive.polite}) {
    if (mode == AriaLive.assertive) {
      assertiveMessage.value = message;
    } else {
      politeMessage.value = message;
    }
  }

  /// Convenience shortcut for polite announcements (waits until user is idle).
  void announcePolite(String message) => announce(message, mode: AriaLive.polite);

  /// Convenience shortcut for assertive announcements (interrupts user immediately).
  void announceAssertive(String message) => announce(message, mode: AriaLive.assertive);

  /// Clears both announcement channels.
  void clear() {
    politeMessage.value = '';
    assertiveMessage.value = '';
  }
}

/// Declarative live region descriptor that exposes announcements to assistive technologies.
///
/// Embeds hidden polite and assertive live sub-regions that react to [BloomAnnouncer] updates.
///
/// Place this once near the root of your application descriptor tree:
///
/// ```dart
/// Div(
///   children: [
///     LiveRegion(),
///     MainContent(),
///   ],
/// )
/// ```
class LiveRegion extends ElNode {
  LiveRegion({
    BloomAnnouncer? announcer,
    String? className,
    String? style,
    Map<String, String>? attrs,
  }) : super(
          'div',
          className: cx([visuallyHiddenClass, className]),
          style: style != null ? '$visuallyHiddenStyle $style' : visuallyHiddenStyle,
          attrs: {
            ...?attrs,
            'id': 'bloom-live-announcer',
          },
          children: [
            El(
              'div',
              attrs: aria(
                live: AriaLive.polite,
                atomic: true,
                relevant: AriaRelevant.additionsText,
              ),
              children: [
                Live(() => Text((announcer ?? BloomAnnouncer.instance).politeMessage.value)),
              ],
            ),
            El(
              'div',
              attrs: aria(
                live: AriaLive.assertive,
                atomic: true,
                relevant: AriaRelevant.additionsText,
              ),
              children: [
                Live(() => Text((announcer ?? BloomAnnouncer.instance).assertiveMessage.value)),
              ],
            ),
          ],
        );
}

/// A standalone single live region descriptor bound to a specific message signal.
///
/// ```dart
/// final statusSignal = signal('Connecting...');
///
/// AriaLiveRegion(
///   mode: AriaLive.polite,
///   message: statusSignal,
/// )
/// ```
class AriaLiveRegion extends ElNode {
  AriaLiveRegion({
    required AriaLive mode,
    required ReadonlySignal<String> message,
    bool atomic = true,
    String? className,
    String? style,
    Map<String, String>? attrs,
  }) : super(
          'div',
          className: cx([visuallyHiddenClass, className]),
          style: style != null ? '$visuallyHiddenStyle $style' : visuallyHiddenStyle,
          attrs: {
            ...?attrs,
            ...aria(
              live: mode,
              atomic: atomic,
            ),
          },
          children: [
            Live(() => Text(message.value)),
          ],
        );
}
