// lib/src/observability/navigation_observer.dart
import 'package:flutter/widgets.dart';
import 'models.dart';
import 'observability.dart';

/// NavigatorObserver that automatically records route transition breadcrumbs.
class BloomObservabilityNavigatorObserver extends NavigatorObserver {
  final String category;

  BloomObservabilityNavigatorObserver({this.category = 'navigation'});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final routeName = route.settings.name ?? route.runtimeType.toString();
    final prevName = previousRoute?.settings.name ?? previousRoute?.runtimeType.toString();

    BloomObservability.addBreadcrumb(
      category: category,
      message: 'Navigated to $routeName${prevName != null ? ' from $prevName' : ''}',
      level: BloomBreadcrumbLevel.info,
      data: {
        'to': routeName,
        if (prevName != null) 'from': prevName,
        if (route.settings.arguments != null) 'arguments': route.settings.arguments.toString(),
      },
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final routeName = route.settings.name ?? route.runtimeType.toString();
    final prevName = previousRoute?.settings.name ?? previousRoute?.runtimeType.toString();

    BloomObservability.addBreadcrumb(
      category: category,
      message: 'Popped $routeName${prevName != null ? ', back to $prevName' : ''}',
      level: BloomBreadcrumbLevel.info,
      data: {
        'popped': routeName,
        if (prevName != null) 'current': prevName,
      },
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final newName = newRoute?.settings.name ?? newRoute?.runtimeType.toString();
    final oldName = oldRoute?.settings.name ?? oldRoute?.runtimeType.toString();

    BloomObservability.addBreadcrumb(
      category: category,
      message: 'Replaced $oldName with $newName',
      level: BloomBreadcrumbLevel.info,
      data: {
        if (newName != null) 'to': newName,
        if (oldName != null) 'from': oldName,
      },
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    final routeName = route.settings.name ?? route.runtimeType.toString();

    BloomObservability.addBreadcrumb(
      category: category,
      message: 'Removed route $routeName',
      level: BloomBreadcrumbLevel.info,
      data: {'removed': routeName},
    );
  }
}
