class ApiEndpoints {
  static const String base = '/api';

  // Auth
  static const String login = '$base/auth/login';
  static const String signup = '$base/auth/signup';
  static const String refresh = '$base/auth/refresh';
  static const String logout = '$base/auth/logout';
  static const String me = '$base/auth/me';

  // Workspaces
  static const String workspaces = '$base/workspaces';
  static String workspaceById(String id) => '$base/workspaces/$id';
  static String workspaceMembers(String id) => '$base/workspaces/$id/members';
  static String workspaceInvite(String id) => '$base/workspaces/$id/members/invite';
  static String workspaceMemberById(String workspaceId, String userId) =>
      '$base/workspaces/$workspaceId/members/$userId';

  // Projects
  static const String projects = '$base/projects';
  static String projectById(String id) => '$base/projects/$id';
  static String projectArchive(String id) => '$base/projects/$id/archive';
  static String projectSections(String id) => '$base/projects/$id/sections';

  // Sections
  static const String sections = '$base/sections';
  static String sectionById(String id) => '$base/sections/$id';

  // Tasks
  static const String tasks = '$base/tasks';
  static String taskById(String id) => '$base/tasks/$id';
  static String taskComplete(String id) => '$base/tasks/$id/complete';
  static const String taskBulkComplete = '$base/tasks/bulk-complete';
  static String taskMove(String id) => '$base/tasks/$id/move';
  static const String tasksToday = '$base/tasks/today';
  static const String tasksUpcoming = '$base/tasks/upcoming';
  static const String tasksInbox = '$base/tasks/inbox';

  // Labels
  static const String labels = '$base/labels';
  static String labelById(String id) => '$base/labels/$id';

  // Comments & Activity
  static const String comments = '$base/comments';
  static String commentById(String id) => '$base/comments/$id';

  // Notifications
  static const String notifications = '$base/notifications';
  static String notificationRead(String id) => '$base/notifications/$id/read';
  static const String notificationsReadAll = '$base/notifications/read-all';

  // Search
  static const String search = '$base/search';
}
