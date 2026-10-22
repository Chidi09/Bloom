import 'events.dart';
import 'framework.dart';

/// Converts nested child values into Bloom nodes.
///
/// Strings and numbers become text, iterables are flattened, and null/false
/// values are omitted. Other values throw [ArgumentError].
///
/// ```dart
/// final children = nodes(['Hello ', Strong(text: 'world')]);
/// ```
List<BloomNode> nodes(List<Object?> children) {
  final result = <BloomNode>[];
  void add(Object? child) {
    if (child == null || child == false) return;
    if (child is BloomNode) {
      result.add(child);
    } else if (child is String) {
      result.add(TextNode(child));
    } else if (child is num) {
      result.add(TextNode(child.toString()));
    } else if (child is Iterable) {
      for (final item in child) {
        add(item);
      }
    } else {
      throw ArgumentError('Unsupported child type: ${child.runtimeType}');
    }
  }

  for (final child in children) {
    add(child);
  }
  return result;
}

ElNode _el(
  String tag,
  List<Object?> children, {
  String? cls,
  String? id,
  String? style,
  Map<String, String>? attrs,
  Map<String, String>? data,
  Map<String, BloomEventHandler>? on,
  BloomEventHandler? onClick,
  String Function()? reactiveClass,
  String Function()? reactiveStyle,
  Map<String, Object? Function()>? reactiveAttrs,
  Map<String, bool Function()>? classIf,
  Map<String, String>? extraAttrs,
}) {
  final mergedAttrs = <String, String>{};
  if (id != null) mergedAttrs['id'] = id;
  if (data != null) {
    for (final entry in data.entries) {
      mergedAttrs['data-${entry.key}'] = entry.value;
    }
  }
  if (extraAttrs != null) mergedAttrs.addAll(extraAttrs);
  if (attrs != null) mergedAttrs.addAll(attrs);
  final mergedOn = <String, BloomEventHandler>{...?on};
  if (onClick != null) mergedOn['click'] = onClick;
  return ElNode(
    tag,
    className: cls,
    style: style,
    attrs: mergedAttrs.isEmpty ? null : mergedAttrs,
    on: mergedOn.isEmpty ? null : mergedOn,
    children: nodes(children),
    reactiveClass: reactiveClass,
    reactiveStyle: reactiveStyle,
    reactiveAttrs: reactiveAttrs,
    classIf: classIf,
  );
}

/// Builds a `<div>` from concise child values.
///
/// ```dart
/// div([h2(['Title']), p(['Hello ', strong(['world'])])], cls: 'card');
/// ```
ElNode div(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('div', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);

/// Builds a `<span>` element.
ElNode span(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('span', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<p>` element.
ElNode p(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('p', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<section>` element.
ElNode section(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('section', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<article>` element.
ElNode article(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('article', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<header>` element.
ElNode header(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('header', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<footer>` element.
ElNode footer(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('footer', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<nav>` element.
ElNode nav(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('nav', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<main>` element.
ElNode main(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('main', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<aside>` element.
ElNode aside(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('aside', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<h1>` element.
ElNode h1(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('h1', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<h2>` element.
ElNode h2(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('h2', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<h3>` element.
ElNode h3(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('h3', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<h4>` element.
ElNode h4(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('h4', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<h5>` element.
ElNode h5(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('h5', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<h6>` element.
ElNode h6(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('h6', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<ul>` element.
ElNode ul(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('ul', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<ol>` element.
ElNode ol(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('ol', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<li>` element.
ElNode li(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('li', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<dl>` element.
ElNode dl(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('dl', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<dt>` element.
ElNode dt(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('dt', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<dd>` element.
ElNode dd(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('dd', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<strong>` element.
ElNode strong(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('strong', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<em>` element.
ElNode em(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('em', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<small>` element.
ElNode small(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('small', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<code>` element.
ElNode code(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('code', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<pre>` element.
ElNode pre(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('pre', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<blockquote>` element.
ElNode blockquote(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('blockquote', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<figure>` element.
ElNode figure(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('figure', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<figcaption>` element.
ElNode figcaption(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('figcaption', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<label>` element.
ElNode label(List<Object?> children, {String? htmlFor, String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('label', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf, extraAttrs: htmlFor == null ? null : {'for': htmlFor});
/// Builds a `<form>` element.
ElNode form(List<Object?> children, {String? action, String? method, String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('form', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf, extraAttrs: {if (action != null) 'action': action, if (method != null) 'method': method});
/// Builds a `<table>` element.
ElNode table(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('table', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<thead>` element.
ElNode thead(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('thead', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<tbody>` element.
ElNode tbody(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('tbody', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<tfoot>` element.
ElNode tfoot(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('tfoot', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<tr>` element.
ElNode tr(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('tr', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<th>` element.
ElNode th(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('th', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<td>` element.
ElNode td(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('td', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<a>` element.
///
/// ```dart
/// a(['Read more'], href: '/story');
/// ```
ElNode a(List<Object?> children, {required String href, String? target, String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('a', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf, extraAttrs: {'href': href, if (target != null) 'target': target});
/// Builds a `<button>` element.
ElNode button(List<Object?> children, {String? type, String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('button', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf, extraAttrs: {if (type != null) 'type': type});
/// Builds a `<select>` element.
ElNode select(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('select', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<option>` element.
ElNode option(List<Object?> children, {String? value, bool? selected, String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('option', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf, extraAttrs: {if (value != null) 'value': value, if (selected != null) 'selected': selected.toString()});
/// Builds a `<textarea>` element.
ElNode textarea(List<Object?> children, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el('textarea', children, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);

/// Builds an `<img>` element.
///
/// ```dart
/// img(src: '/logo.svg', alt: 'Logo');
/// ```
ElNode img({required String src, required String alt, String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _voidEl('img', {'src': src, 'alt': alt}, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<input>` element.
ElNode input({String? type, String? name, String? value, String? placeholder, String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _voidEl('input', {if (type != null) 'type': type, if (name != null) 'name': name, if (value != null) 'value': value, if (placeholder != null) 'placeholder': placeholder}, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds a `<br>` element.
ElNode br({String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _voidEl('br', const {}, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);
/// Builds an `<hr>` element.
ElNode hr({String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _voidEl('hr', const {}, cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf);

ElNode _voidEl(String tag, Map<String, String> extraAttrs, {String? cls, String? id, String? style, Map<String, String>? attrs, Map<String, String>? data, Map<String, BloomEventHandler>? on, BloomEventHandler? onClick, String Function()? reactiveClass, String Function()? reactiveStyle, Map<String, Object? Function()>? reactiveAttrs, Map<String, bool Function()>? classIf}) => _el(tag, const [], cls: cls, id: id, style: style, attrs: attrs, data: data, on: on, onClick: onClick, reactiveClass: reactiveClass, reactiveStyle: reactiveStyle, reactiveAttrs: reactiveAttrs, classIf: classIf, extraAttrs: extraAttrs);
