import 'package:go_router/go_router.dart';
import 'guards.dart';
import '../routes/index.dart';
import '../routes/error.dart';
import '../routes/(auth)/login.dart';
import '../routes/(auth)/signup.dart';
import '../routes/(app)/_layout.dart';
import '../routes/(app)/today/index.dart';
import '../routes/(app)/upcoming/index.dart';
import '../routes/(app)/inbox/index.dart';
import '../routes/(app)/projects/index.dart';
import '../routes/(app)/projects/[id]/index.dart';
import '../routes/(app)/task/[id].dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => ErrorPage(state: state),
    redirect: (context, state) => AuthGuard.redirect(state.uri.toString()),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const IndexPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppLayout(child: child),
        routes: [
          GoRoute(
            path: '/today',
            builder: (context, state) => const TodayPage(),
          ),
          GoRoute(
            path: '/upcoming',
            builder: (context, state) => const UpcomingPage(),
          ),
          GoRoute(
            path: '/inbox',
            builder: (context, state) => const InboxPage(),
          ),
          GoRoute(
            path: '/projects',
            builder: (context, state) => const ProjectsPage(),
          ),
          GoRoute(
            path: '/projects/:id',
            builder: (context, state) => ProjectDetailPage(
              projectId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/task/:id',
            builder: (context, state) => TaskDetailPage(
              taskId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
}
