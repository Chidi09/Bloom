import '../framework.dart';
import '../signals.dart';
import 'cn.dart';
import 'empty.dart';
import 'input.dart';
import 'table.dart';

/// Column definition for [dataTable].
class DataTableColumn<T> {
  /// Unique column identifier.
  final String id;

  /// Header label displayed in `<th>`.
  final String header;

  /// Cell builder for a row of type [T].
  final BloomNode Function(T row) cell;

  /// Optional sort key extractor; enables clickable column sorting when set.
  final Comparable<Object?> Function(T row)? sortBy;

  /// Extra CSS classes applied to cells in this column.
  final String extraClassName;

  /// Creates a [DataTableColumn].
  const DataTableColumn({
    required this.id,
    required this.header,
    required this.cell,
    this.sortBy,
    this.extraClassName = '',
  });
}

/// Interactive data table with optional client-side search filtering and column sorting.
BloomNode dataTable<T>({
  required List<DataTableColumn<T>> columns,
  required List<T> rows,
  String Function(T row)? searchText,
  String? searchPlaceholder,
  String emptyTitle = 'No results',
  void Function(T row)? onRowClick,
  String extraClassName = '',
}) {
  final filterQuery = signal<String>('');
  final sortColumnId = signal<String?>(null);
  final sortAscending = signal<bool>(true);

  return Div(
    className: cn(['w-full space-y-3', extraClassName]),
    children: [
      if (searchText != null)
        textInput(
          id: 'data-table-filter',
          placeholder: searchPlaceholder ?? 'Filter rows...',
          onInput: (e) => filterQuery.value = e.value ?? '',
        ),
      Live(() {
        final q = filterQuery.value.trim().toLowerCase();
        var visible = q.isEmpty || searchText == null
            ? List<T>.of(rows)
            : rows
                .where((r) => searchText(r).toLowerCase().contains(q))
                .toList();

        final activeSortId = sortColumnId.value;
        if (activeSortId != null) {
          final col =
              columns.where((c) => c.id == activeSortId).firstOrNull;
          final keyFn = col?.sortBy;
          if (keyFn != null) {
            final asc = sortAscending.value;
            visible.sort((a, b) {
              final cmp = keyFn(a).compareTo(keyFn(b));
              return asc ? cmp : -cmp;
            });
          }
        }

        if (visible.isEmpty) {
          return empty(title: emptyTitle);
        }

        return table(
          children: [
            tableHeader(
              children: [
                tableRow(
                  children: [
                    for (final col in columns)
                      tableHead(
                        extraClassName: col.extraClassName,
                        children: [
                          if (col.sortBy != null)
                            Button(
                              attrs: {'type': 'button'},
                              className:
                                  'inline-flex items-center gap-1 font-medium hover:text-[var(--text)]',
                              onClick: (_) {
                                if (sortColumnId.value == col.id) {
                                  sortAscending.value = !sortAscending.value;
                                } else {
                                  sortColumnId.value = col.id;
                                  sortAscending.value = true;
                                }
                              },
                              text: sortColumnId.value == col.id
                                  ? '${col.header} ${sortAscending.value ? '↑' : '↓'}'
                                  : col.header,
                            )
                          else
                            Text(col.header),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            tableBody(
              children: [
                for (final row in visible)
                  tableRow(
                    onClick:
                        onRowClick == null ? null : (_) => onRowClick(row),
                    children: [
                      for (final col in columns)
                        tableCell(
                          extraClassName: col.extraClassName,
                          children: [col.cell(row)],
                        ),
                    ],
                  ),
              ],
            ),
          ],
        );
      }),
    ],
  );
}
