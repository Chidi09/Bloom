class QueryKeys {
  static List<dynamic> currentUser() => ['auth', 'me'];

  static List<dynamic> workspaces() => ['workspaces'];
  static List<dynamic> workspace(String id) => ['workspaces', id];
  static List<dynamic> workspaceMembers(String workspaceId) => [
    'workspaces',
    workspaceId,
    'members',
  ];

  static List<dynamic> projects(String workspaceId) => [
    'projects',
    'workspace',
    workspaceId,
  ];
  static List<dynamic> project(String id) => ['projects', id];
  static List<dynamic> projectSections(String projectId) => [
    'projects',
    projectId,
    'sections',
  ];

  static List<dynamic> tasks({
    String? workspaceId,
    String? projectId,
    String? filter,
  }) => [
    'tasks',
    if (workspaceId != null) 'workspace:$workspaceId',
    if (projectId != null) 'project:$projectId',
    if (filter != null) 'filter:$filter',
  ];

  static List<dynamic> task(String id) => ['tasks', 'detail', id];
  static List<dynamic> taskComments(String taskId) => [
    'tasks',
    taskId,
    'comments',
  ];

  static List<dynamic> labels(String workspaceId) => [
    'labels',
    'workspace',
    workspaceId,
  ];

  static List<dynamic> notifications(String userId) => [
    'notifications',
    'user',
    userId,
  ];

  static List<dynamic> search(String query, {String? workspaceId}) => [
    'search',
    query,
    if (workspaceId != null) workspaceId,
  ];
}
